#include "platform/windows/windows_selection_service.hpp"

#include <QClipboard>
#include <QCoreApplication>
#include <QImage>
#include <QMimeData>
#include <QStringList>
#include <QUrl>
#include <chrono>
#include <memory>
#include <optional>
#include <thread>

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <ole2.h>
#include <UIAutomation.h>

namespace ohmytypeless {

namespace {

class ScopedComInit {
public:
    ScopedComInit() {
        hr_ = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    }

    ~ScopedComInit() {
        if (SUCCEEDED(hr_)) {
            ::CoUninitialize();
        }
    }

    HRESULT result() const {
        return hr_;
    }

private:
    HRESULT hr_ = E_FAIL;
};

struct WindowTarget {
    HWND window = nullptr;
    HWND focus = nullptr;
    DWORD thread_id = 0;
};

template <typename T>
class ComPtr {
public:
    ~ComPtr() {
        reset();
    }

    T** put() {
        reset();
        return &ptr_;
    }

    T* get() const {
        return ptr_;
    }

    T* operator->() const {
        return ptr_;
    }

    explicit operator bool() const {
        return ptr_ != nullptr;
    }

    void reset() {
        if (ptr_ != nullptr) {
            ptr_->Release();
            ptr_ = nullptr;
        }
    }

private:
    T* ptr_ = nullptr;
};

QString format_hresult(HRESULT hr) {
    return QString("0x%1").arg(static_cast<quint32>(hr), 8, 16, QChar('0'));
}

bool is_valid_window(HWND hwnd) {
    return hwnd != nullptr && ::IsWindow(hwnd) != FALSE;
}

bool is_current_process_window(HWND hwnd) {
    if (!is_valid_window(hwnd)) {
        return false;
    }

    DWORD process_id = 0;
    ::GetWindowThreadProcessId(hwnd, &process_id);
    return process_id == ::GetCurrentProcessId();
}

QString format_hwnd(HWND hwnd) {
    return is_valid_window(hwnd) ? QString("0x%1").arg(reinterpret_cast<quintptr>(hwnd), 0, 16) : "null";
}

QString window_class_name(HWND hwnd) {
    if (!is_valid_window(hwnd)) {
        return "n/a";
    }

    wchar_t buffer[256] = {};
    const int length = ::GetClassNameW(hwnd, buffer, static_cast<int>(std::size(buffer)));
    return length > 0 ? QString::fromWCharArray(buffer, length) : "unknown";
}

bool supports_wm_paste(HWND hwnd) {
    const QString class_name = window_class_name(hwnd);
    return class_name == "Edit" || class_name.startsWith("RichEdit", Qt::CaseInsensitive);
}

WindowTarget capture_foreground_target() {
    WindowTarget target;
    target.window = ::GetForegroundWindow();
    if (!is_valid_window(target.window)) {
        return target;
    }

    target.thread_id = ::GetWindowThreadProcessId(target.window, nullptr);
    GUITHREADINFO info{};
    info.cbSize = sizeof(info);
    if (target.thread_id != 0 && ::GetGUIThreadInfo(target.thread_id, &info) != FALSE) {
        if (is_valid_window(info.hwndFocus)) {
            target.focus = info.hwndFocus;
        } else if (is_valid_window(info.hwndActive)) {
            target.focus = info.hwndActive;
        }
        if (is_valid_window(info.hwndActive)) {
            target.window = ::GetAncestor(info.hwndActive, GA_ROOT);
        }
    }

    if (!is_valid_window(target.focus)) {
        target.focus = target.window;
    }
    if (!is_valid_window(target.window)) {
        target.window = target.focus;
    }
    return target;
}

bool send_wm_paste(HWND hwnd) {
    if (!is_valid_window(hwnd)) {
        return false;
    }

    DWORD_PTR result = 0;
    return ::SendMessageTimeoutW(hwnd,
                                 WM_PASTE,
                                 0,
                                 0,
                                 SMTO_ABORTIFHUNG | SMTO_BLOCK,
                                 250,
                                 &result) != 0;
}

QString bstr_to_qstring(BSTR text) {
    if (text == nullptr) {
        return {};
    }
    return QString::fromWCharArray(text, ::SysStringLen(text));
}

QString control_type_name(CONTROLTYPEID control_type) {
    switch (control_type) {
    case UIA_DocumentControlTypeId:
        return "Document";
    case UIA_EditControlTypeId:
        return "Edit";
    case UIA_TextControlTypeId:
        return "Text";
    case UIA_PaneControlTypeId:
        return "Pane";
    default:
        return QString("ControlType(%1)").arg(control_type);
    }
}

QString element_summary(IUIAutomationElement* element) {
    if (element == nullptr) {
        return "element=null";
    }

    BSTR name = nullptr;
    BSTR class_name = nullptr;
    CONTROLTYPEID control_type = 0;
    element->get_CurrentName(&name);
    element->get_CurrentClassName(&class_name);
    element->get_CurrentControlType(&control_type);

    const QString summary =
        QString("name=%1 class=%2 type=%3").arg(bstr_to_qstring(name), bstr_to_qstring(class_name), control_type_name(control_type));
    if (name != nullptr) {
        ::SysFreeString(name);
    }
    if (class_name != nullptr) {
        ::SysFreeString(class_name);
    }
    return summary;
}

IUIAutomationElement* focused_element(IUIAutomation* automation) {
    if (automation == nullptr) {
        return nullptr;
    }
    IUIAutomationElement* element = nullptr;
    if (FAILED(automation->GetFocusedElement(&element))) {
        return nullptr;
    }
    return element;
}

QString selected_text_from_element(IUIAutomationElement* element, QStringList* debug_lines) {
    if (element == nullptr) {
        if (debug_lines != nullptr) {
            debug_lines->append("focused element unavailable");
        }
        return {};
    }

    if (debug_lines != nullptr) {
        debug_lines->append(QString("focused element: %1").arg(element_summary(element)));
    }

    ComPtr<IUIAutomationTextPattern> text_pattern;
    const HRESULT pattern_hr =
        element->GetCurrentPatternAs(UIA_TextPatternId, __uuidof(IUIAutomationTextPattern), reinterpret_cast<void**>(text_pattern.put()));
    if (FAILED(pattern_hr) || !text_pattern) {
        if (debug_lines != nullptr) {
            debug_lines->append(QString("TextPattern unavailable: %1").arg(format_hresult(pattern_hr)));
        }
        return {};
    }

    ComPtr<IUIAutomationTextRangeArray> selection_ranges;
    const HRESULT selection_hr = text_pattern->GetSelection(selection_ranges.put());
    if (FAILED(selection_hr) || !selection_ranges) {
        if (debug_lines != nullptr) {
            debug_lines->append(QString("GetSelection failed: %1").arg(format_hresult(selection_hr)));
        }
        return {};
    }

    int length = 0;
    selection_ranges->get_Length(&length);
    if (debug_lines != nullptr) {
        debug_lines->append(QString("selection range count=%1").arg(length));
    }
    if (length <= 0) {
        return {};
    }

    QStringList parts;
    for (int index = 0; index < length; ++index) {
        ComPtr<IUIAutomationTextRange> range;
        if (FAILED(selection_ranges->GetElement(index, range.put())) || !range) {
            continue;
        }

        BSTR text = nullptr;
        if (FAILED(range->GetText(-1, &text))) {
            continue;
        }
        parts << bstr_to_qstring(text);
        if (text != nullptr) {
            ::SysFreeString(text);
        }
    }
    return parts.join("");
}

std::unique_ptr<QMimeData> clone_mime_data(const QMimeData* source) {
    auto clone = std::make_unique<QMimeData>();
    if (source == nullptr) {
        return clone;
    }

    if (source->hasText()) {
        clone->setText(source->text());
    }
    if (source->hasHtml()) {
        clone->setHtml(source->html());
    }
    if (source->hasUrls()) {
        clone->setUrls(source->urls());
    }
    if (source->hasImage()) {
        clone->setImageData(qvariant_cast<QImage>(source->imageData()));
    }

    const QStringList formats = source->formats();
    for (const QString& format : formats) {
        if (format == "text/plain" || format == "text/html" || format == "text/uri-list") {
            continue;
        }
        clone->setData(format, source->data(format));
    }
    return clone;
}

bool open_clipboard_with_retry() {
    for (int attempt = 0; attempt < 12; ++attempt) {
        if (::OpenClipboard(nullptr) != FALSE) {
            return true;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(25));
    }
    return false;
}

std::optional<QString> read_clipboard_text_native() {
    if (!open_clipboard_with_retry()) {
        return std::nullopt;
    }

    std::optional<QString> result;
    HANDLE handle = ::GetClipboardData(CF_UNICODETEXT);
    if (handle != nullptr) {
        const wchar_t* text = static_cast<const wchar_t*>(::GlobalLock(handle));
        if (text != nullptr) {
            result = QString::fromWCharArray(text);
            ::GlobalUnlock(handle);
        }
    }
    ::CloseClipboard();
    return result;
}

bool set_clipboard_text_native(const QString& text) {
    if (!open_clipboard_with_retry()) {
        return false;
    }

    const std::size_t bytes = static_cast<std::size_t>(text.size() + 1) * sizeof(wchar_t);
    HGLOBAL memory = ::GlobalAlloc(GMEM_MOVEABLE, bytes);
    if (memory == nullptr) {
        ::CloseClipboard();
        return false;
    }

    wchar_t* buffer = static_cast<wchar_t*>(::GlobalLock(memory));
    if (buffer == nullptr) {
        ::GlobalFree(memory);
        ::CloseClipboard();
        return false;
    }

    std::memcpy(buffer, text.utf16(), static_cast<std::size_t>(text.size()) * sizeof(wchar_t));
    buffer[text.size()] = L'\0';
    ::GlobalUnlock(memory);

    ::EmptyClipboard();
    if (::SetClipboardData(CF_UNICODETEXT, memory) == nullptr) {
        ::GlobalFree(memory);
        ::CloseClipboard();
        return false;
    }

    ::CloseClipboard();
    return true;
}

bool clear_clipboard_native() {
    if (!open_clipboard_with_retry()) {
        return false;
    }
    const bool ok = ::EmptyClipboard() != FALSE;
    ::CloseClipboard();
    return ok;
}

void restore_clipboard_text_native(const std::optional<QString>& snapshot_text) {
    if (!snapshot_text.has_value()) {
        return;
    }
    set_clipboard_text_native(snapshot_text.value());
}

bool send_ctrl_shortcut(WORD key) {
    INPUT inputs[4] = {};
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = VK_CONTROL;
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = key;
    inputs[2].type = INPUT_KEYBOARD;
    inputs[2].ki.wVk = key;
    inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;
    inputs[3].type = INPUT_KEYBOARD;
    inputs[3].ki.wVk = VK_CONTROL;
    inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;
    return ::SendInput(static_cast<UINT>(std::size(inputs)), inputs, sizeof(INPUT)) == std::size(inputs);
}

QString summarize_clipboard_native() {
    const std::optional<QString> text = read_clipboard_text_native();
    if (!text.has_value()) {
        return "clipboard text unavailable";
    }
    return QString("nativeTextLength=%1").arg(text->size());
}

}  // namespace

WindowsSelectionService::WindowsSelectionService(QClipboard* clipboard) : clipboard_(clipboard) {}

QString WindowsSelectionService::backend_name() const {
    return "windows_uia_textpattern";
}

SelectionCaptureResult WindowsSelectionService::capture_selection() {
    QStringList lines;

    ScopedComInit com_init;
    if (FAILED(com_init.result()) && com_init.result() != RPC_E_CHANGED_MODE) {
        set_debug_info(QString("selection capture failed: CoInitializeEx=%1").arg(format_hresult(com_init.result())));
        return SelectionCaptureResult{.success = false, .selected_text = {}, .debug_info = last_debug_info_};
    }

    ComPtr<IUIAutomation> automation;
    const HRESULT create_hr =
        ::CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(automation.put()));
    if (FAILED(create_hr) || !automation) {
        set_debug_info(QString("selection capture failed: CoCreateInstance=%1").arg(format_hresult(create_hr)));
        return SelectionCaptureResult{.success = false, .selected_text = {}, .debug_info = last_debug_info_};
    }

    IUIAutomationElement* raw_element = focused_element(automation.get());
    const QString selected_text = selected_text_from_element(raw_element, &lines);
    if (raw_element != nullptr) {
        raw_element->Release();
    }
    if (!selected_text.isEmpty()) {
        lines << "capture path=uia_textpattern";
        lines << QString("selected_text_length=%1").arg(selected_text.size());
        set_debug_info(lines.join('\n'));
        return SelectionCaptureResult{
            .success = true,
            .selected_text = selected_text,
            .debug_info = last_debug_info_,
        };
    }

    if (clipboard_ == nullptr) {
        lines << "clipboard fallback unavailable";
        set_debug_info(lines.join('\n'));
        return SelectionCaptureResult{
            .success = false,
            .selected_text = {},
            .debug_info = last_debug_info_,
        };
    }

    const std::optional<QString> snapshot_text = read_clipboard_text_native();
    clear_clipboard_native();
    const bool shortcut_sent = send_ctrl_shortcut('C');
    std::this_thread::sleep_for(std::chrono::milliseconds(120));
    QCoreApplication::processEvents();
    const QString copied_text = read_clipboard_text_native().value_or(QString());
    lines << "capture path=clipboard_ctrl_c";
    lines << QString("copy_shortcut_sent=%1").arg(shortcut_sent ? "true" : "false");
    lines << QString("clipboard after copy: %1").arg(summarize_clipboard_native());
    lines << QString("copied_text_length=%1").arg(copied_text.size());
    restore_clipboard_text_native(snapshot_text);
    lines << QString("clipboard restored_text_length=%1").arg(snapshot_text.has_value() ? snapshot_text->size() : 0);
    set_debug_info(lines.join('\n'));

    return SelectionCaptureResult{
        .success = shortcut_sent && !copied_text.isEmpty(),
        .selected_text = copied_text,
        .debug_info = last_debug_info_,
    };
}

bool WindowsSelectionService::replace_selection(const QString& text) {
    if (clipboard_ == nullptr) {
        set_debug_info("replace failed: clipboard backend is null");
        return false;
    }

    const std::optional<QString> snapshot_text = read_clipboard_text_native();
    const bool clipboard_set = set_clipboard_text_native(text);
    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    const WindowTarget target = capture_foreground_target();
    HWND paste_hwnd = nullptr;
    if (is_valid_window(target.focus) && !is_current_process_window(target.focus)) {
        paste_hwnd = target.focus;
    } else if (is_valid_window(target.window) && !is_current_process_window(target.window)) {
        paste_hwnd = target.window;
    }

    bool sent = false;
    QStringList lines;
    lines << "replace path=clipboard_ctrl_v"
          << QString("clipboard_set=%1").arg(clipboard_set ? "true" : "false")
          << QString("target_window=%1 class=%2")
                 .arg(format_hwnd(paste_hwnd), window_class_name(paste_hwnd));

    if (clipboard_set && supports_wm_paste(paste_hwnd) && send_wm_paste(paste_hwnd)) {
        sent = true;
        lines << "paste_route=wm_paste";
    } else {
        sent = clipboard_set && send_ctrl_shortcut('V');
        lines << "paste_route=ctrl_v";
    }

    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    restore_clipboard_text_native(snapshot_text);

    lines << QString("paste_shortcut_sent=%1").arg(sent ? "true" : "false")
          << QString("text_length=%1").arg(text.size())
          << QString("clipboard restored_text_length=%1").arg(snapshot_text.has_value() ? snapshot_text->size() : 0);
    set_debug_info(lines.join('\n'));
    return clipboard_set && sent;
}

QString WindowsSelectionService::last_debug_info() const {
    return last_debug_info_;
}

void WindowsSelectionService::set_debug_info(const QString& text) {
    last_debug_info_ = text;
    ::OutputDebugStringW(reinterpret_cast<LPCWSTR>(text.utf16()));
    ::OutputDebugStringW(L"\n");
}

}  // namespace ohmytypeless
