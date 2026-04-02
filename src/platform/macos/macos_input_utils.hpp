#pragma once

#include <QString>

#include <sys/types.h>

namespace ohmytypeless {

bool macos_preflight_listen_event_access();
bool macos_request_listen_event_access();
bool macos_preflight_post_event_access();
bool macos_request_post_event_access();
bool macos_preflight_accessibility_access();
bool macos_request_accessibility_access();

QString macos_global_hotkey_permission_reason();
QString macos_auto_paste_permission_reason();
QString macos_accessibility_permission_reason();

pid_t macos_frontmost_process_id();
bool macos_is_current_process(pid_t pid);
bool macos_capture_frontmost_external_process(pid_t* pid, QString* debug_info);
bool macos_activate_process(pid_t pid, QString* debug_info);
bool macos_send_paste_shortcut(pid_t pid, const QString& paste_keys, QString* debug_info);

}  // namespace ohmytypeless
