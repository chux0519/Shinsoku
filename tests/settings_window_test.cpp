#include "ui/settings_window.hpp"

#include <QApplication>
#include <QCheckBox>
#include <QComboBox>
#include <QDateTime>
#include <QLabel>
#include <QListWidget>
#include <QPushButton>
#include <QSpinBox>
#include <QLineEdit>
#include <QToolButton>

#include <iostream>
#include <stdexcept>
#include <string>

namespace {

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

template <typename Widget>
Widget* required_widget(ohmytypeless::SettingsWindow& window, const char* object_name) {
    Widget* widget = window.findChild<Widget*>(object_name);
    require(widget != nullptr, std::string("missing settings widget: ") + object_name);
    return widget;
}

}  // namespace

int main(int argc, char* argv[]) {
    QApplication application(argc, argv);

    try {
        ohmytypeless::ProfileConfig dictation;
        dictation.id = "dictation";
        dictation.name = "Dictation";

        ohmytypeless::ProfileConfig translation;
        translation.id = "translate";
        translation.name = "Chinese To English";

        ohmytypeless::SettingsWindow window;
        window.set_profiles({dictation, translation}, "dictation");
        window.set_recent_target_apps({{"com.apple.mail", "Mail"}, {"com.tinyspeck.slackmacgap", "Slack"}});
        window.set_app_profile_rules(true,
                                     {{.enabled = true,
                                       .app_id = "com.apple.mail",
                                       .app_name = "Mail",
                                       .profile_id = "dictation"}});

        require(window.auto_profile_selection_enabled(), "the automatic selection switch must reflect loaded settings");
        require(window.app_profile_rules().size() == 1U, "loaded application rules must be available to Apply");

        auto* app_combo = required_widget<QComboBox>(window, "appProfileRuleAppCombo");
        auto* profile_combo = required_widget<QComboBox>(window, "appProfileRuleProfileCombo");
        auto* add_button = required_widget<QPushButton>(window, "appProfileRuleAddButton");
        auto* remove_button = required_widget<QPushButton>(window, "appProfileRuleRemoveButton");
        auto* rule_list = required_widget<QListWidget>(window, "appProfileRuleList");
        auto* navigation = required_widget<QListWidget>(window, "settingsNav");
        auto* status = required_widget<QLabel>(window, "appProfileRuleStatus");
        auto* nearby_enabled = required_widget<QCheckBox>(window, "nearbyEnabledCheck");
        auto* nearby_port = required_widget<QSpinBox>(window, "nearbyPortSpin");
        auto* nearby_pair = required_widget<QPushButton>(window, "nearbyPairButton");
        auto* nearby_pairing_code = required_widget<QLabel>(window, "nearbyPairingCodeLabel");
        auto* nearby_clients = required_widget<QListWidget>(window, "nearbyTrustedClientList");
        auto* nearby_revoke = required_widget<QPushButton>(window, "nearbyRevokeButton");
        auto* adapter_enabled = required_widget<QCheckBox>(window, "deviceAdapterEnabledCheck");
        auto* adapter_path = required_widget<QLineEdit>(window, "deviceAdapterPathEdit");
        auto* adapter_browse = required_widget<QToolButton>(window, "deviceAdapterBrowseButton");
        auto* adapter_status = required_widget<QLabel>(window, "deviceAdapterStatusLabel");

        app_combo->setCurrentIndex(app_combo->findData("com.apple.mail"));
        profile_combo->setCurrentIndex(profile_combo->findData("translate"));
        add_button->click();
        require(window.app_profile_rules().size() == 1U,
                "adding an existing application must update its rule instead of creating a conflict");
        require(window.app_profile_rules().front().profile_id == "translate",
                "an existing application rule must update to the newly selected Profile");

        rule_list->setCurrentRow(0);
        remove_button->click();
        require(window.app_profile_rules().empty(), "Remove must delete the selected application rule");

        window.set_app_profile_rules(true,
                                     {{.enabled = true,
                                       .app_id = "com.example.missing",
                                       .app_name = "Missing",
                                       .profile_id = "deleted-profile"}});
        require(status->text().contains("invalid or conflicting"),
                "a missing target Profile must produce a visible fallback warning");

        window.set_nearby_enabled(true);
        window.set_nearby_port(40123);
        require(window.nearby_enabled() && window.nearby_port() == 40123,
                "Nearby controls must expose values to Apply");
        require(!nearby_pair->isEnabled(), "pairing must remain unavailable while the server is stopped");

        int pairing_requests = 0;
        QString revoked_client;
        QObject::connect(&window, &ohmytypeless::SettingsWindow::nearby_pairing_requested,
                         [&]() { ++pairing_requests; });
        QObject::connect(&window, &ohmytypeless::SettingsWindow::nearby_revoke_requested,
                         [&](const QString& client_id) { revoked_client = client_id; });
        window.set_nearby_runtime_status(true, true, "Shinsoku Desktop", 40123, QString(64, 'a'));
        require(nearby_pair->isEnabled(), "a running server must enable pairing");
        nearby_pair->click();
        require(pairing_requests == 1, "the pairing button must request a new limited-time code");
        window.set_nearby_pairing_code("42", QDateTime::currentMSecsSinceEpoch() + 120000);
        require(nearby_pairing_code->text().contains("42"), "the active pairing code must be visible");

        window.set_nearby_trusted_clients({{"ios-client", "Yongsheng's iPhone · ios"}});
        require(nearby_clients->count() == 1, "trusted Nearby devices must be listed");
        nearby_clients->setCurrentRow(0);
        require(nearby_revoke->isEnabled(), "selecting a trusted device must enable revocation");
        nearby_revoke->click();
        require(revoked_client == "ios-client", "revocation must use the opaque client ID");

        window.set_device_adapter_enabled(true);
        window.set_device_adapter_executable_path("/tmp/shinsoku-device-adapter");
        require(window.device_adapter_enabled(), "device adapter enable state must be available to Apply");
        require(window.device_adapter_executable_path() == "/tmp/shinsoku-device-adapter",
                "device adapter executable path must be available to Apply");
        require(adapter_enabled->isChecked() && !adapter_path->text().isEmpty() &&
                    !adapter_browse->icon().isNull(),
                "device adapter controls must expose an enabled state, path, and browse icon");
        window.set_device_adapter_runtime_status(
            true, true, true, "Runtime Fixture", "1.0.0", "Fixture Microphone", {"usb", "bluetooth"});
        require(adapter_status->text().contains("Runtime Fixture 1.0.0") &&
                    adapter_status->text().contains("Fixture Microphone connected") &&
                    adapter_status->text().contains("usb, bluetooth"),
                "device adapter runtime identity, device, and permissions must be visible");

        if (argc == 3 && std::string(argv[1]) == "--screenshot") {
            navigation->setCurrentRow(4);
            window.show();
            application.processEvents();
            require(window.grab().save(QString::fromLocal8Bit(argv[2])),
                    "the Settings visual test must save its screenshot");
        }

        std::cout << "settings_window_tests: passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << "settings_window_tests: " << exception.what() << '\n';
        return 1;
    }
}
