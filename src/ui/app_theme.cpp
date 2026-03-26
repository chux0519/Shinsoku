#include "ui/app_theme.hpp"

#include <QApplication>
#include <QColor>
#include <QFile>
#include <QPalette>
#include <QHash>
#include <QStyleFactory>
#include <QStyleHints>
#include <QFont>

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

    QFont font(QStringLiteral("Noto Sans"));
    if (!font.exactMatch()) {
        font = QFont(QStringLiteral("DejaVu Sans"));
    }
    font.setStyleHint(QFont::SansSerif);
    font.setPointSize(11);
    app.setFont(font);

    const QString bg = dark ? "#16181b" : "#f3f4f6";
    const QString panel = dark ? "#1d2126" : "#ffffff";
    const QString border = dark ? "rgba(255,255,255,0.08)" : "rgba(17,19,21,0.08)";
    const QString panel_border_strong = dark ? "rgba(255,255,255,0.12)" : "rgba(17,19,21,0.10)";
    const QString text = dark ? "#f3f4f6" : "#111315";
    const QString muted = dark ? "#aeb6c0" : "#5f6873";
    const QString badge_bg = dark ? "#262b32" : "#f1f3f5";
    const QString badge_text = dark ? "#e5e7eb" : "#2f3740";
    const QString button_bg = dark ? "#20242a" : "#fafafa";
    const QString button_bg_disabled = dark ? "#1a1e23" : "#eef1f4";
    const QString button_hover = dark ? "rgba(255,255,255,0.05)" : "rgba(17,19,21,0.03)";
    const QString primary = dark ? "#f3f4f6" : "#111315";
    const QString primary_hover = dark ? "#ffffff" : "#2b3137";
    const QString primary_text = dark ? "#111315" : "#ffffff";
    const QString nav_hover = dark ? "rgba(255,255,255,0.06)" : "rgba(17,19,21,0.045)";
    const QString nav_selected_border = dark ? "rgba(255,255,255,0.18)" : "rgba(17,19,21,0.12)";
    const QString input_bg = dark ? "#171a1f" : "#ffffff";
    const QString status_bg = dark ? "#1d2126" : "#ffffff";
    const QString control_border = dark ? "rgba(255,255,255,0.16)" : "rgba(17,19,21,0.16)";
    const QString focus_border = dark ? "#d7dde5" : "#2f3740";
    const QString control_fill = dark ? "#272c33" : "#eef1f4";
    const QString disabled_border = dark ? "rgba(255,255,255,0.06)" : "rgba(17,19,21,0.06)";
    const QString text_disabled = dark ? "#717a85" : "#98a1ab";
    const QString scrollbar_track = dark ? "#1a1d22" : "#eceef1";
    const QString scrollbar_handle = dark ? "rgba(174,182,192,0.52)" : "rgba(95,104,115,0.42)";
    const QString scrollbar_handle_hover = dark ? "rgba(223,228,235,0.72)" : "rgba(47,55,64,0.58)";
    const QString selection_text = dark ? "#16181b" : "#ffffff";
    const QString list_selection_bg = dark ? "rgba(255,255,255,0.04)" : "rgba(17,19,21,0.035)";
    const QString list_selection_border = dark ? "rgba(255,255,255,0.10)" : "rgba(17,19,21,0.08)";
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
            {"panel_border_strong", panel_border_strong},
            {"text", text},
            {"muted", muted},
            {"badge_bg", badge_bg},
            {"badge_text", badge_text},
            {"button_bg", button_bg},
            {"button_bg_disabled", button_bg_disabled},
            {"button_hover", button_hover},
            {"primary", primary},
            {"primary_hover", primary_hover},
            {"primary_text", primary_text},
            {"nav_hover", nav_hover},
            {"nav_selected_border", nav_selected_border},
            {"input_bg", input_bg},
            {"status_bg", status_bg},
            {"control_border", control_border},
            {"focus_border", focus_border},
            {"control_fill", control_fill},
            {"disabled_border", disabled_border},
            {"text_disabled", text_disabled},
            {"scrollbar_track", scrollbar_track},
            {"scrollbar_handle", scrollbar_handle},
            {"scrollbar_handle_hover", scrollbar_handle_hover},
            {"selection_text", selection_text},
            {"list_selection_bg", list_selection_bg},
            {"list_selection_border", list_selection_border},
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
