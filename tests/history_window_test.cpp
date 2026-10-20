#include "ui/history_window.hpp"

#include <QApplication>
#include <QLabel>
#include <QListWidget>

#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

ohmytypeless::HistoryEntry entry(std::int64_t id,
                                 std::string created_at,
                                 std::string text,
                                 std::string app_name,
                                 std::string profile_name) {
    return ohmytypeless::HistoryEntry{
        .id = id,
        .created_at = std::move(created_at),
        .text = std::move(text),
        .meta = {{"source", {{"app_id", "com.example.app"}, {"app_name", std::move(app_name)}}},
                 {"profile", {{"id", "profile"}, {"name", std::move(profile_name)}}}},
    };
}

}  // namespace

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    try {
        ohmytypeless::HistoryWindow window;
        const std::vector<ohmytypeless::HistoryEntry> entries = {
            entry(3, "2026-08-20 11:30:00", "Newest", "Mail", "Dictation"),
            entry(2, "2026-08-20 10:15:00", "Same day", "Notes", "Polish"),
            entry(1, "2026-08-19 09:00:00", "Older", "Slack", "Translate"),
        };
        window.set_entries(entries);

        auto* list = window.findChild<QListWidget*>();
        require(list != nullptr, "history list widget should exist");
        require(list->count() == 5, "three entries across two dates should render two date separators");
        require(list->item(0)->flags() == Qt::NoItemFlags, "date separators must not be interactive");
        require(!list->item(0)->data(Qt::UserRole).isValid(), "date separators must not carry a history ID");

        QWidget* first_entry_widget = list->itemWidget(list->item(1));
        require(first_entry_widget != nullptr, "history entries should have a rendered widget");
        bool found_context_header = false;
        for (QLabel* label : first_entry_widget->findChildren<QLabel*>()) {
            if (label->text().contains("Mail") && label->text().contains("Dictation")) {
                found_context_header = true;
                break;
            }
        }
        require(found_context_header, "entry header should show source application and Profile");

        window.append_entries({entry(0, "2026-08-19 08:00:00", "Oldest", "Terminal", "Command")});
        require(list->count() == 6, "appending the same date group should not duplicate its separator");

        std::cout << "history_window_tests: passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << "history_window_tests: " << exception.what() << '\n';
        return 1;
    }
}
