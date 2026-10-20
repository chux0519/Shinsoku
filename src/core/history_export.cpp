#include "core/history_export.hpp"

#include <QDateTime>
#include <QString>
#include <QTimeZone>

namespace ohmytypeless {

nlohmann::json public_history_entry_json(const HistoryEntry& entry, const HistoryExportOptions& options) {
    QDateTime created_at = QDateTime::fromString(QString::fromStdString(entry.created_at), "yyyy-MM-dd HH:mm:ss");
    if (created_at.isValid()) {
        created_at.setTimeZone(QTimeZone::UTC);
    }
    nlohmann::json output = {
        {"id", entry.id},
        {"created_at", created_at.isValid() ? created_at.toString(Qt::ISODate).toStdString() : entry.created_at},
        {"text", entry.text},
    };

    if (entry.meta.is_object()) {
        if (const auto source = entry.meta.find("source"); source != entry.meta.end() && source->is_object()) {
            nlohmann::json public_source = nlohmann::json::object();
            for (const char* key : {"app_id", "app_name"}) {
                if (source->contains(key) && (*source)[key].is_string()) {
                    public_source[key] = (*source)[key];
                }
            }
            if (!public_source.empty()) {
                output["source"] = std::move(public_source);
            }
        }
        if (const auto profile = entry.meta.find("profile"); profile != entry.meta.end() && profile->is_object()) {
            nlohmann::json public_profile = nlohmann::json::object();
            for (const char* key : {"id", "name", "selection"}) {
                if (profile->contains(key) && (*profile)[key].is_string()) {
                    public_profile[key] = (*profile)[key];
                }
            }
            if (!public_profile.empty()) {
                output["profile"] = std::move(public_profile);
            }
        }
    }
    if (options.include_meta) {
        output["meta"] = entry.meta;
    }
    if (options.include_audio_path && entry.audio_path.has_value()) {
        output["audio_path"] = entry.audio_path->generic_string();
    }
    return output;
}

}  // namespace ohmytypeless
