#pragma once

class QApplication;
class QString;

namespace ohmytypeless {

void install_app_theme(QApplication& app);
void set_app_theme_preference(QApplication& app, const QString& preference);

}  // namespace ohmytypeless
