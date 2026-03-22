#include "core/app_controller.hpp"
#include "platform/qt/qt_clipboard_service.hpp"
#include "platform/qt/qt_hud_presenter.hpp"
#include "platform/windows/windows_global_hotkey.hpp"
#include "ui/main_window.hpp"

#include <QApplication>

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    app.setApplicationName("OhMyTypeless");
    app.setOrganizationName("ohmytypeless");
    app.setQuitOnLastWindowClosed(false);

    ohmytypeless::MainWindow window;
    ohmytypeless::QtClipboardService clipboard(app.clipboard());
    ohmytypeless::WindowsGlobalHotkey hotkey;
    ohmytypeless::QtHudPresenter hud;
    ohmytypeless::AppController controller(&window, &clipboard, &hotkey, &hud);

    controller.initialize();
    window.show();

    return app.exec();
}
