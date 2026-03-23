#include "core/app_controller.hpp"
#include "platform/qt/qt_clipboard_service.hpp"
#include "platform/qt/qt_global_hotkey.hpp"
#include "platform/qt/qt_hud_presenter.hpp"
#include "ui/main_window.hpp"

#include <QApplication>
#include <QColor>
#include <QPalette>
#include <QStyleHints>
#include <QStyleFactory>

#ifdef Q_OS_WIN
#include "platform/windows/windows_clipboard_service.hpp"
#include "platform/windows/windows_global_hotkey.hpp"
#endif

namespace {

void apply_app_theme(QApplication& app, Qt::ColorScheme scheme) {
    const bool dark = scheme == Qt::ColorScheme::Dark;

    QPalette palette;
    palette.setColor(QPalette::Window, dark ? QColor("#16181b") : QColor("#f3f4f6"));
    palette.setColor(QPalette::WindowText, dark ? QColor("#f3f4f6") : QColor("#111315"));
    palette.setColor(QPalette::Base, dark ? QColor("#1d2126") : QColor("#ffffff"));
    palette.setColor(QPalette::AlternateBase, dark ? QColor("#242931") : QColor("#eceef1"));
    palette.setColor(QPalette::Text, dark ? QColor("#f3f4f6") : QColor("#16181b"));
    palette.setColor(QPalette::Button, dark ? QColor("#20242a") : QColor("#fafafa"));
    palette.setColor(QPalette::ButtonText, dark ? QColor("#f3f4f6") : QColor("#16181b"));
    palette.setColor(QPalette::Highlight, dark ? QColor("#8f98a3") : QColor("#4b5563"));
    palette.setColor(QPalette::HighlightedText, QColor("#ffffff"));
    palette.setColor(QPalette::PlaceholderText, dark ? QColor("#87909c") : QColor("#7b8490"));
    palette.setColor(QPalette::ToolTipBase, dark ? QColor("#20242a") : QColor("#ffffff"));
    palette.setColor(QPalette::ToolTipText, dark ? QColor("#f3f4f6") : QColor("#16181b"));
    app.setPalette(palette);

    const QString bg = dark ? "#16181b" : "#f3f4f6";
    const QString panel = dark ? "#1d2126" : "#ffffff";
    const QString panel_alt = dark ? "#20242a" : "#fafafa";
    const QString border = dark ? "rgba(255,255,255,0.08)" : "rgba(17,19,21,0.08)";
    const QString text = dark ? "#f3f4f6" : "#111315";
    const QString muted = dark ? "#9aa3ad" : "#5f6873";
    const QString badge_bg = dark ? "#262b32" : "#f1f3f5";
    const QString badge_text = dark ? "#e5e7eb" : "#2f3740";
    const QString button_bg = dark ? "#20242a" : "#fafafa";
    const QString button_hover = dark ? "#272c33" : "#f2f4f6";
    const QString primary = dark ? "#f3f4f6" : "#111315";
    const QString primary_text = dark ? "#111315" : "#ffffff";
    const QString input_bg = dark ? "#171a1f" : "#ffffff";
    const QString status_bg = dark ? "#1d2126" : "#ffffff";
    const QString control_border = dark ? "rgba(255,255,255,0.16)" : "rgba(17,19,21,0.16)";
    const QString control_fill = dark ? "#272c33" : "#eef1f4";
    const QString scrollbar_track = dark ? "#1a1d22" : "#eceef1";
    const QString scrollbar_handle = dark ? "#5f6873" : "#8b949e";

    app.setStyleSheet(QString(
        "QMainWindow, QDialog, QWidget { background: %1; color: %2; font-size: 14px; }"
        "QScrollArea { border: none; background: transparent; }"
        "QScrollArea > QWidget > QWidget { background: transparent; }"
        "#heroCard, #statusCard, #actionCard, #headerCard, #sectionCard, #statusBanner, #historyHeader, #entryCard, #summaryCard {"
        "background: %3; border: 1px solid %4; border-radius: 16px; }"
        "#eyebrow, #headerEyebrow, #historyEyebrow { color: %5; font-size: 12px; font-weight: 700; letter-spacing: 0.5px; }"
        "#heroTitle, #headerTitle, #historyTitle { color: %2; font-weight: 700; }"
        "#heroTitle { font-size: 26px; }"
        "#headerTitle, #historyTitle { font-size: 24px; }"
        "#heroBody, #headerBody, #historyBody, #entrySummary, #statusText { color: %6; }"
        "#stateBadge { background: %7; color: %8; border: 1px solid %4; border-radius: 10px; padding: 7px 10px; font-weight: 700; }"
        "#entryHeader, #summaryLabel { color: %2; font-weight: 700; }"
        "#entryPreview { color: %2; font-size: 15px; }"
        "QGroupBox#sectionCard { margin-top: 0; padding-top: 8px; font-weight: 700; color: %2; }"
        "QGroupBox#sectionCard::title { subcontrol-origin: margin; left: 22px; top: 14px; padding: 0 6px 0 0; }"
        "QLabel { background: transparent; }"
        "QListWidget { background: transparent; border: none; outline: none; }"
        "QListWidget::item { background: transparent; border: none; }"
        "QLineEdit, QPlainTextEdit, QComboBox, QSpinBox, QDoubleSpinBox {"
        "background: %9; border: 1px solid %16; border-radius: 10px; padding: 9px 11px; selection-background-color: %5; selection-color: %10; }"
        "QPlainTextEdit { padding: 10px; }"
        "QComboBox { padding-right: 34px; }"
        "QComboBox::drop-down {"
        "subcontrol-origin: padding; subcontrol-position: top right; width: 28px;"
        "border-left: 1px solid %16; background: %17;"
        "border-top-right-radius: 10px; border-bottom-right-radius: 10px; }"
        "QComboBox::down-arrow { width: 10px; height: 10px; }"
        "QCheckBox { spacing: 8px; color: %2; }"
        "QCheckBox::indicator { width: 18px; height: 18px; }"
        "QCheckBox::indicator:unchecked { background: %9; border: 2px solid %16; border-radius: 6px; }"
        "QCheckBox::indicator:checked { background: %13; border: 2px solid %13; border-radius: 6px; }"
        "QCheckBox::indicator:hover { border-color: %2; }"
        "QPushButton { background: %11; border: 1px solid %4; border-radius: 10px; padding: 10px 15px; font-weight: 600; color: %2; }"
        "QPushButton:hover { background: %12; }"
        "QPushButton:pressed { background: %7; }"
        "#recordButton, #applyButton { background: %13; color: %14; border: none; }"
        "#recordButton:hover, #applyButton:hover { background: %8; color: %14; }"
        "#statusBanner { background: %15; color: %6; padding: 14px 16px; }"
        "QScrollBar:vertical { background: %18; width: 12px; margin: 2px; border-radius: 6px; }"
        "QScrollBar::handle:vertical { background: %19; min-height: 28px; border-radius: 6px; }"
        "QScrollBar::handle:vertical:hover { background: %2; }"
        "QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0px; }"
        "QScrollBar:horizontal { background: %18; height: 12px; margin: 2px; border-radius: 6px; }"
        "QScrollBar::handle:horizontal { background: %19; min-width: 28px; border-radius: 6px; }"
        "QScrollBar::handle:horizontal:hover { background: %2; }"
        "QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal { width: 0px; }"
        )
        .arg(bg, text, panel, border, muted, muted, badge_bg, dark ? "#ffffff" : "#2f3740", input_bg, dark ? "#16181b" : "#ffffff",
             button_bg, button_hover, primary, primary_text, status_bg, control_border, control_fill, scrollbar_track, scrollbar_handle));
}

}  // namespace

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    app.setApplicationName("OhMyTypeless");
    app.setOrganizationName("ohmytypeless");
    app.setQuitOnLastWindowClosed(false);
    app.setStyle(QStyleFactory::create("Fusion"));
    apply_app_theme(app, app.styleHints()->colorScheme());
    QObject::connect(app.styleHints(), &QStyleHints::colorSchemeChanged, &app,
                     [&app](Qt::ColorScheme scheme) { apply_app_theme(app, scheme); });

    ohmytypeless::MainWindow window;
#ifdef Q_OS_WIN
    ohmytypeless::WindowsClipboardService clipboard(app.clipboard());
    ohmytypeless::WindowsGlobalHotkey hotkey;
#else
    ohmytypeless::QtClipboardService clipboard(app.clipboard());
    ohmytypeless::QtGlobalHotkey hotkey;
#endif
    ohmytypeless::QtHudPresenter hud;
    ohmytypeless::AppController controller(&window, &clipboard, &hotkey, &hud);

    controller.initialize();
    window.show();

    return app.exec();
}
