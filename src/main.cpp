#include "core/app_controller.hpp"
#include "platform/linux/linux_pulseaudio_audio_capture_service.hpp"
#include "platform/miniaudio_audio_capture_service.hpp"
#include "platform/qt/qt_clipboard_service.hpp"
#include "platform/qt/qt_global_hotkey.hpp"
#include "platform/qt/qt_hud_presenter.hpp"
#include "platform/qt/qt_selection_service.hpp"
#include "platform/wayland/wayland_clipboard_service.hpp"
#include "platform/wayland/wayland_global_hotkey.hpp"
#include "platform/wayland/wayland_layer_shell_hud_presenter.hpp"
#include "platform/wayland/wayland_selection_service.hpp"
#include "ui/app_theme.hpp"
#include "ui/main_window.hpp"

#include <QApplication>
#include <QGuiApplication>
#include <QString>

#include <memory>

#ifdef Q_OS_WIN
#include "platform/windows/windows_clipboard_service.hpp"
#include "platform/windows/windows_global_hotkey.hpp"
#include "platform/windows/windows_selection_service.hpp"
#endif

int main(int argc, char* argv[]) {
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
        Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);
    QApplication app(argc, argv);
    app.setApplicationName("OhMyTypeless");
    app.setOrganizationName("ohmytypeless");
    app.setQuitOnLastWindowClosed(false);
    ohmytypeless::install_app_theme(app);

    ohmytypeless::MainWindow window;
#ifdef Q_OS_WIN
    ohmytypeless::MiniaudioAudioCaptureService audio_capture;
    ohmytypeless::WindowsClipboardService clipboard(app.clipboard());
    ohmytypeless::WindowsSelectionService selection(app.clipboard());
    ohmytypeless::WindowsGlobalHotkey hotkey;
#elif defined(Q_OS_LINUX)
    const QString platform_name = QGuiApplication::platformName().toLower();
    const bool is_wayland = platform_name.contains("wayland");
    ohmytypeless::LinuxPulseaudioAudioCaptureService audio_capture;
    std::unique_ptr<ohmytypeless::ClipboardService> clipboard_impl;
    std::unique_ptr<ohmytypeless::SelectionService> selection_impl;
    std::unique_ptr<ohmytypeless::GlobalHotkey> hotkey_impl;
    std::unique_ptr<ohmytypeless::HudPresenter> hud_impl;
    if (is_wayland) {
        clipboard_impl = std::make_unique<ohmytypeless::WaylandClipboardService>(app.clipboard());
        selection_impl = std::make_unique<ohmytypeless::WaylandSelectionService>(app.clipboard());
        hotkey_impl = std::make_unique<ohmytypeless::WaylandGlobalHotkey>();
        hud_impl = std::make_unique<ohmytypeless::WaylandLayerShellHudPresenter>(&window);
    } else {
        clipboard_impl = std::make_unique<ohmytypeless::QtClipboardService>(app.clipboard());
        selection_impl = std::make_unique<ohmytypeless::QtSelectionService>(app.clipboard());
        hotkey_impl = std::make_unique<ohmytypeless::QtGlobalHotkey>();
        hud_impl = std::make_unique<ohmytypeless::QtHudPresenter>(&window);
    }
#else
    ohmytypeless::MiniaudioAudioCaptureService audio_capture;
    ohmytypeless::QtClipboardService clipboard(app.clipboard());
    ohmytypeless::QtSelectionService selection(app.clipboard());
    ohmytypeless::QtGlobalHotkey hotkey;
#endif
#ifdef Q_OS_LINUX
    ohmytypeless::AppController controller(&window,
                                           clipboard_impl.get(),
                                           &audio_capture,
                                           selection_impl.get(),
                                           hotkey_impl.get(),
                                           hud_impl.get());
#else
    ohmytypeless::QtHudPresenter hud(&window);
    ohmytypeless::AppController controller(&window, &clipboard, &audio_capture, &selection, &hotkey, &hud);
#endif

    controller.initialize();
    window.show();

    return app.exec();
}
