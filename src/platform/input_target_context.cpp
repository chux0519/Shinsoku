#include "platform/input_target_context.hpp"

#include <utility>

namespace ohmytypeless {

namespace {

bool contains_any(const QString& value, const QStringList& needles) {
    for (const QString& needle : needles) {
        if (value.contains(needle, Qt::CaseInsensitive)) {
            return true;
        }
    }
    return false;
}

}  // namespace

InputTargetContext classify_input_target(QString app_id,
                                         QString app_name,
                                         QString field_role,
                                         bool field_inspection_available,
                                         bool secure_field,
                                         const QStringList& field_hints) {
    InputTargetContext context{
        .app_id = std::move(app_id),
        .app_name = std::move(app_name),
        .field_role = std::move(field_role),
    };

    const QString app_identity = context.app_id + " " + context.app_name;
    if (contains_any(app_identity,
                     {"com.apple.systempreferences", "com.apple.systemsettings", "systemsettings.exe"})) {
        context.privacy = InputTargetPrivacy::Sensitive;
        context.privacy_reason = "system_settings";
        return context;
    }

    if (secure_field) {
        context.privacy = InputTargetPrivacy::Sensitive;
        context.privacy_reason = "secure_field";
        return context;
    }

    QString field_identity = context.field_role;
    for (const QString& hint : field_hints) {
        field_identity += " " + hint;
    }

    if (contains_any(field_identity,
                     {"password", "passcode", "one-time code", "verification code", "security code", "pin field",
                      "pin code", "security pin", "secret", "token", "api key", "api-key", "access key",
                      "access-key", "private key", "credential", "authorization"})) {
        context.privacy = InputTargetPrivacy::Sensitive;
        context.privacy_reason = "credential_field";
        return context;
    }

    if (contains_any(field_identity,
                     {"search field", "searchfield", "omnibox", "address bar", "address and search", "location bar",
                      "website address", "search or enter", "url field"})) {
        context.privacy = InputTargetPrivacy::Sensitive;
        context.privacy_reason = "search_or_address_field";
        return context;
    }

    context.privacy = field_inspection_available ? InputTargetPrivacy::Normal : InputTargetPrivacy::Unknown;
    if (!field_inspection_available) {
        context.privacy_reason = "field_inspection_unavailable";
    }
    return context;
}

const char* input_target_privacy_name(InputTargetPrivacy privacy) {
    switch (privacy) {
    case InputTargetPrivacy::Normal:
        return "normal";
    case InputTargetPrivacy::Sensitive:
        return "sensitive";
    case InputTargetPrivacy::Unknown:
    default:
        return "unknown";
    }
}

}  // namespace ohmytypeless
