#include "core/app_controller.hpp"
#include "platform/qt/qt_clipboard_service.hpp"
#include "platform/qt/qt_global_hotkey.hpp"
#include "platform/qt/qt_hud_presenter.hpp"
#include "ui/app_theme.hpp"
#include "ui/main_window.hpp"

#include <QApplication>
#include <QGuiApplication>

#ifdef Q_OS_WIN
#include "platform/windows/windows_clipboard_service.hpp"
#include "platform/windows/windows_global_hotkey.hpp"
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
