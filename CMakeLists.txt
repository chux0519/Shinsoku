cmake_minimum_required(VERSION 3.24)

project(OhMyTypeless VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Concurrent Core Gui Svg Widgets)
find_package(CURL REQUIRED)
find_package(ixwebsocket CONFIG REQUIRED)
find_package(MbedTLS CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(unofficial-sqlite3 CONFIG REQUIRED)
find_path(MINIAUDIO_INCLUDE_DIRS miniaudio.h REQUIRED)

if(UNIX AND NOT APPLE)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(LIBEVDEV REQUIRED IMPORTED_TARGET libevdev)
    pkg_check_modules(LIBPULSE REQUIRED IMPORTED_TARGET libpulse)
    pkg_check_modules(LIBPULSE_SIMPLE REQUIRED IMPORTED_TARGET libpulse-simple)
endif()

option(OHMYTYPELESS_ENABLE_WAYLAND_LAYER_SHELL_HUD "Enable Wayland HUD via in-tree layer-shell backend" ON)

qt_standard_project_setup()

qt_add_executable(ohmytypeless
    resources/app_theme.qrc
    src/main.cpp
    src/core/app_config.hpp
    src/core/app_config.cpp
    src/core/app_state.hpp
    src/core/backend/asr_backend.hpp
    src/core/backend/streaming_asr_backend.hpp
    src/core/backend/streaming/websocket_transport_options.hpp
    src/core/backend/streaming/websocket_transport_options.cpp
    src/core/backend/streaming/ix_proxy_socket.hpp
    src/core/backend/streaming/ix_proxy_socket.cpp
    src/core/backend/streaming/bailian/bailian_streaming_asr_backend.hpp
    src/core/backend/streaming/bailian/bailian_streaming_asr_backend.cpp
    src/core/backend/streaming/soniox/soniox_streaming_asr_backend.hpp
    src/core/backend/streaming/soniox/soniox_streaming_asr_backend.cpp
    src/core/backend/text_transform_backend.hpp
    src/core/backend/backend_factory.hpp
    src/core/backend/backend_factory.cpp
    src/core/asr_client.hpp
    src/core/asr_client.cpp
    src/core/app_controller.hpp
    src/core/app_controller.cpp
    src/core/curl_support.hpp
    src/core/curl_support.cpp
    src/core/history_store.hpp
    src/core/history_store.cpp
    src/core/recording_store.hpp
    src/core/recording_store.cpp
    src/core/task_types.hpp
    src/core/text_refiner.hpp
    src/core/text_refiner.cpp
    src/core/wav_encoder.hpp
    src/core/wav_encoder.cpp
    src/platform/clipboard_service.hpp
    src/platform/audio_capture_service.hpp
    src/platform/global_hotkey.hpp
    src/platform/hotkey_names.hpp
    src/platform/hotkey_names.cpp
    src/platform/hud_presenter.hpp
    src/platform/miniaudio_audio_capture_service.hpp
    src/platform/miniaudio_audio_capture_service.cpp
    src/platform/selection_service.hpp
    src/platform/qt/qt_clipboard_service.hpp
    src/platform/qt/qt_clipboard_service.cpp
    src/platform/qt/qt_global_hotkey.hpp
    src/platform/qt/qt_global_hotkey.cpp
    src/platform/qt/qt_hud_presenter.hpp
    src/platform/qt/qt_hud_presenter.cpp
    src/platform/qt/qt_selection_service.hpp
    src/platform/qt/qt_selection_service.cpp
    src/ui/app_theme.hpp
    src/ui/app_theme.cpp
    src/ui/main_window.hpp
    src/ui/main_window.cpp
    src/ui/meeting_transcription_window.hpp
    src/ui/meeting_transcription_window.cpp
    src/ui/history_details_dialog.hpp
    src/ui/history_details_dialog.cpp
    src/ui/settings_window.hpp
    src/ui/settings_window.cpp
    src/ui/history_window.hpp
    src/ui/history_window.cpp
)

if(WIN32)
    target_sources(ohmytypeless PRIVATE
        src/platform/windows/windows_clipboard_service.hpp
        src/platform/windows/windows_clipboard_service.cpp
        src/platform/windows/windows_global_hotkey.hpp
        src/platform/windows/windows_global_hotkey.cpp
        src/platform/windows/windows_selection_service.hpp
        src/platform/windows/windows_selection_service.cpp
    )
endif()

if(UNIX AND NOT APPLE)
    target_sources(ohmytypeless PRIVATE
        src/platform/linux/linux_pulseaudio_audio_capture_service.hpp
        src/platform/linux/linux_pulseaudio_audio_capture_service.cpp
        src/platform/wayland/wayland_clipboard_service.hpp
        src/platform/wayland/wayland_clipboard_service.cpp
        src/platform/wayland/wayland_global_hotkey.hpp
        src/platform/wayland/wayland_global_hotkey.cpp
        src/platform/wayland/qwayland_layer_shell_integration.hpp
        src/platform/wayland/qwayland_layer_shell_integration.cpp
        src/platform/wayland/qwayland_layer_surface.hpp
        src/platform/wayland/qwayland_layer_surface.cpp
        src/platform/wayland/wayland_layer_shell_hud_presenter.hpp
        src/platform/wayland/wayland_layer_shell_hud_presenter.cpp
        src/platform/wayland/wayland_selection_service.hpp
        src/platform/wayland/wayland_selection_service.cpp
        src/platform/wayland/wlr-layer-shell-unstable-v1.xml
    )
endif()

target_include_directories(ohmytypeless PRIVATE src ${MINIAUDIO_INCLUDE_DIRS})

target_link_libraries(ohmytypeless PRIVATE
    CURL::libcurl
    Qt6::Concurrent
    Qt6::Core
    Qt6::Gui
    Qt6::Svg
    Qt6::Widgets
    ixwebsocket::ixwebsocket
    MbedTLS::mbedtls
    MbedTLS::mbedx509
    MbedTLS::mbedcrypto
    nlohmann_json::nlohmann_json
    unofficial::sqlite3::sqlite3
)

if(UNIX AND NOT APPLE)
    set(OHMYTYPELESS_QT_STATIC_PLUGINS)
    foreach(plugin_target
        Qt6::QWaylandIntegrationPlugin
        Qt6::QWaylandXdgShellIntegrationPlugin
        Qt6::QWaylandEglClientBufferPlugin
        Qt6::QWaylandBradientDecorationPlugin
        Qt6::QWaylandAdwaitaDecorationPlugin
        Qt6::QWaylandWlShellIntegrationPlugin
    )
        if(TARGET ${plugin_target})
            list(APPEND OHMYTYPELESS_QT_STATIC_PLUGINS ${plugin_target})
        endif()
    endforeach()

    if(OHMYTYPELESS_QT_STATIC_PLUGINS)
        qt_import_plugins(ohmytypeless INCLUDE ${OHMYTYPELESS_QT_STATIC_PLUGINS})
    endif()
endif()

get_target_property(QT_QMAKE_EXECUTABLE Qt6::qmake IMPORTED_LOCATION)
get_filename_component(QT_BIN_DIR "${QT_QMAKE_EXECUTABLE}" DIRECTORY)
get_filename_component(QT_HOST_PREFIX "${QT_BIN_DIR}" DIRECTORY)
get_filename_component(QT_HOST_PREFIX "${QT_HOST_PREFIX}" DIRECTORY)
get_filename_component(QT_VCPKG_PREFIX "${QT_HOST_PREFIX}" DIRECTORY)

if(WIN32)
    add_custom_command(TARGET ohmytypeless POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:ohmytypeless>/platforms"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<$<CONFIG:Debug>:${QT_VCPKG_PREFIX}/debug/Qt6/plugins/platforms/qwindowsd.dll>$<$<NOT:$<CONFIG:Debug>>:${QT_VCPKG_PREFIX}/Qt6/plugins/platforms/qwindows.dll>"
            "$<TARGET_FILE_DIR:ohmytypeless>/platforms/"
        COMMENT "Copying Qt Windows platform plugin"
    )
endif()

if(WIN32)
    target_link_libraries(ohmytypeless PRIVATE bcrypt ole32 uiautomationcore user32)
endif()

if(UNIX AND NOT APPLE)
    target_link_libraries(ohmytypeless PRIVATE PkgConfig::LIBEVDEV PkgConfig::LIBPULSE PkgConfig::LIBPULSE_SIMPLE)
endif()

if(UNIX AND NOT APPLE AND OHMYTYPELESS_ENABLE_WAYLAND_LAYER_SHELL_HUD)
    find_package(Qt6WaylandClientPrivate CONFIG REQUIRED)
    target_link_libraries(ohmytypeless PRIVATE Qt6::WaylandClientPrivate)
    qt6_generate_wayland_protocol_client_sources(ohmytypeless
        PRIVATE_CODE
        FILES
            ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/wayland/wlr-layer-shell-unstable-v1.xml
    )
    target_compile_definitions(ohmytypeless PRIVATE OHMYTYPELESS_HAS_WAYLAND_LAYER_SHELL=1)
endif()

target_compile_options(ohmytypeless PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/W4 /permissive->
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wall -Wextra -Wpedantic>
)
