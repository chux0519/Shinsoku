#pragma once

#include <QString>
#include <QStringList>

namespace ohmytypeless {

enum class InputTargetPrivacy {
    Unknown,
    Normal,
    Sensitive,
};

struct InputTargetContext {
    QString app_id;
    QString app_name;
    QString field_role;
    InputTargetPrivacy privacy = InputTargetPrivacy::Unknown;
    QString privacy_reason;
};

InputTargetContext classify_input_target(QString app_id,
                                         QString app_name,
                                         QString field_role,
                                         bool field_inspection_available,
                                         bool secure_field,
                                         const QStringList& field_hints = {});
const char* input_target_privacy_name(InputTargetPrivacy privacy);

}  // namespace ohmytypeless
