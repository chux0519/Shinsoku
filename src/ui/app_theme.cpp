#include "ui/app_theme.hpp"

#include <QApplication>
#include <QColor>
#include <QFile>
#include <QPalette>
#include <QHash>
#include <QStyleFactory>
#include <QStyleHints>

namespace ohmytypeless {

namespace {

QString load_theme_template() {
    QFile file(":/themes/app.qss");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }
    return QString::fromUtf8(file.readAll());
}

QString render_theme_template(QString style, const QHash<QString, QString>& values) {
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        style.replace(QString("{{%1}}").arg(it.key()), it.value());
    }
    return style;
}

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
    const QString border = dark ? "rgba(255,255,255,0.08)" : "rgba(17,19,21,0.08)";
    const QString text = dark ? "#f3f4f6" : "#111315";
    const QString muted = dark ? "#aeb6c0" : "#5f6873";
    const QString badge_bg = dark ? "#262b32" : "#f1f3f5";
    const QString badge_text = dark ? "#e5e7eb" : "#2f3740";
    const QString button_bg = dark ? "#20242a" : "#fafafa";
    const QString button_hover = dark ? "rgba(255,255,255,0.05)" : "rgba(17,19,21,0.03)";
    const QString primary = dark ? "#f3f4f6" : "#111315";
    const QString primary_hover = dark ? "#ffffff" : "#2b3137";
    const QString primary_text = dark ? "#111315" : "#ffffff";
    const QString input_bg = dark ? "#171a1f" : "#ffffff";
    const QString status_bg = dark ? "#1d2126" : "#ffffff";
    const QString control_border = dark ? "rgba(255,255,255,0.16)" : "rgba(17,19,21,0.16)";
    const QString control_fill = dark ? "#272c33" : "#eef1f4";
    const QString scrollbar_track = dark ? "#1a1d22" : "#eceef1";
    const QString scrollbar_handle = dark ? "rgba(174,182,192,0.52)" : "rgba(95,104,115,0.42)";
    const QString selection_text = dark ? "#16181b" : "#ffffff";
    const QString combo_arrow_icon = dark ? ":/icons/chevron-down-light.xpm" : ":/icons/chevron-down-dark.xpm";
    const QString spin_up_icon = dark ? ":/icons/chevron-up-light.xpm" : ":/icons/chevron-up-dark.xpm";
    const QString spin_down_icon = dark ? ":/icons/chevron-down-light.xpm" : ":/icons/chevron-down-dark.xpm";
    const QString checkbox_check_icon = dark ? ":/icons/check-light.xpm" : ":/icons/check-dark.xpm";

    const QString template_text = load_theme_template();
    app.setStyleSheet(render_theme_template(
        template_text,
        {
            {"bg", bg},
            {"panel", panel},
            {"border", border},
            {"text", text},
            {"muted", muted},
            {"badge_bg", badge_bg},
            {"badge_text", badge_text},
            {"button_bg", button_bg},
            {"button_hover", button_hover},
            {"primary", primary},
            {"primary_hover", primary_hover},
            {"primary_text", primary_text},
            {"input_bg", input_bg},
            {"status_bg", status_bg},
            {"control_border", control_border},
            {"control_fill", control_fill},
            {"scrollbar_track", scrollbar_track},
            {"scrollbar_handle", scrollbar_handle},
            {"selection_text", selection_text},
            {"combo_arrow_icon", combo_arrow_icon},
            {"spin_up_icon", spin_up_icon},
            {"spin_down_icon", spin_down_icon},
            {"checkbox_check_icon", checkbox_check_icon},
        }));
}

}  // namespace

void install_app_theme(QApplication& app) {
    app.setStyle(QStyleFactory::create("Fusion"));
    apply_app_theme(app, app.styleHints()->colorScheme());
    QObject::connect(app.styleHints(), &QStyleHints::colorSchemeChanged, &app,
                     [&app](Qt::ColorScheme scheme) { apply_app_theme(app, scheme); });
}

}  // namespace ohmytypeless
