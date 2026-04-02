cmake_minimum_required(VERSION 3.24)

project(Shinsoku VERSION 0.1.0 LANGUAGES C CXX)

if(APPLE)
    enable_language(OBJCXX)
    set(CMAKE_OBJCXX_STANDARD 20)
    set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
endif()

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
option(SHINSOKU_ENABLE_TRAY_DEBUG "Enable temporary tray debug controls in the main window" OFF)

if(COMMAND qt_standard_project_setup)
    qt_standard_project_setup()
elseif(COMMAND qt6_standard_project_setup)
    qt6_standard_project_setup()
endif()

qt_add_executable(shinsoku
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
    set_target_properties(shinsoku PROPERTIES WIN32_EXECUTABLE TRUE)
endif()

if(WIN32)
    target_sources(shinsoku PRIVATE
        src/platform/windows/windows_clipboard_service.hpp
        src/platform/windows/windows_clipboard_service.cpp
        src/platform/windows/windows_global_hotkey.hpp
        src/platform/windows/windows_global_hotkey.cpp
        src/platform/windows/windows_selection_service.hpp
        src/platform/windows/windows_selection_service.cpp
    )
endif()

if(APPLE)
    target_sources(shinsoku PRIVATE
        src/platform/macos/macos_audio_capture_service.hpp
        src/platform/macos/macos_audio_capture_service.mm
        src/platform/macos/macos_clipboard_service.hpp
        src/platform/macos/macos_clipboard_service.mm
        src/platform/macos/macos_global_hotkey.hpp
        src/platform/macos/macos_global_hotkey.mm
        src/platform/macos/macos_hud_presenter.hpp
        src/platform/macos/macos_hud_presenter.mm
        src/platform/macos/macos_input_utils.hpp
        src/platform/macos/macos_input_utils.mm
        src/platform/macos/macos_selection_service.hpp
        src/platform/macos/macos_selection_service.mm
    )
    set_source_files_properties(
        src/platform/macos/macos_audio_capture_service.mm
        src/platform/macos/macos_clipboard_service.mm
        src/platform/macos/macos_global_hotkey.mm
        src/platform/macos/macos_hud_presenter.mm
        src/platform/macos/macos_input_utils.mm
        src/platform/macos/macos_selection_service.mm
        PROPERTIES
            COMPILE_OPTIONS "-fobjc-arc"
    )
endif()

if(UNIX AND NOT APPLE)
    target_sources(shinsoku PRIVATE
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

target_include_directories(shinsoku PRIVATE src ${MINIAUDIO_INCLUDE_DIRS})

if(SHINSOKU_ENABLE_TRAY_DEBUG)
    target_compile_definitions(shinsoku PRIVATE SHINSOKU_ENABLE_TRAY_DEBUG=1)
endif()

target_link_libraries(shinsoku PRIVATE
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
        qt_import_plugins(shinsoku INCLUDE ${OHMYTYPELESS_QT_STATIC_PLUGINS})
    endif()
endif()

get_target_property(QT_QMAKE_EXECUTABLE Qt6::qmake IMPORTED_LOCATION)
get_filename_component(QT_BIN_DIR "${QT_QMAKE_EXECUTABLE}" DIRECTORY)
get_filename_component(QT_INSTALL_PREFIX "${QT_BIN_DIR}" DIRECTORY)
get_filename_component(QT_HOST_PREFIX "${QT_INSTALL_PREFIX}" DIRECTORY)
get_filename_component(QT_HOST_PREFIX "${QT_HOST_PREFIX}" DIRECTORY)
get_filename_component(QT_VCPKG_PREFIX "${QT_HOST_PREFIX}" DIRECTORY)

if(DEFINED VCPKG_INSTALLED_DIR AND NOT VCPKG_INSTALLED_DIR STREQUAL "")
    set(SHINSOKU_VCPKG_INSTALLED_DIR "${VCPKG_INSTALLED_DIR}")
else()
    set(SHINSOKU_VCPKG_INSTALLED_DIR "${CMAKE_BINARY_DIR}/vcpkg_installed")
endif()

if(WIN32)
    if(DEFINED VCPKG_TARGET_TRIPLET AND NOT VCPKG_TARGET_TRIPLET STREQUAL "")
        set(SHINSOKU_WINDOWS_TRIPLET "${VCPKG_TARGET_TRIPLET}")
    else()
        set(SHINSOKU_WINDOWS_TRIPLET "x64-windows")
    endif()
    set(SHINSOKU_WINDOWS_VCPKG_INSTALLED_DIR "${SHINSOKU_VCPKG_INSTALLED_DIR}/${SHINSOKU_WINDOWS_TRIPLET}")
endif()

if(WIN32)
    find_file(SHINSOKU_QWINDOWS_PLUGIN
        NAMES qwindows.dll qwindowsd.dll
        HINTS
            "${QT_INSTALL_PREFIX}/plugins/platforms"
            "${QT_HOST_PREFIX}/plugins/platforms"
            "${QT_VCPKG_PREFIX}/Qt6/plugins/platforms"
        REQUIRED
    )
    add_custom_command(TARGET shinsoku POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:shinsoku>/platforms"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${SHINSOKU_QWINDOWS_PLUGIN}"
            "$<TARGET_FILE_DIR:shinsoku>/platforms/"
        COMMENT "Copying Qt Windows platform plugin"
    )
endif()

if(WIN32)
    find_program(SHINSOKU_POWERSHELL_EXECUTABLE NAMES pwsh powershell REQUIRED)
    find_program(SHINSOKU_WINDEPLOYQT NAMES windeployqt windeployqt.exe HINTS "${QT_BIN_DIR}" REQUIRED)
    set(SHINSOKU_PACKAGE_OUTPUT_DIR "${CMAKE_BINARY_DIR}/packages")

    add_custom_target(package_windows_portable
        COMMAND ${SHINSOKU_POWERSHELL_EXECUTABLE} -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_SOURCE_DIR}/packaging/windows/package-portable.ps1"
            -AppName "Shinsoku"
            -Version "${PROJECT_VERSION}"
            -Config "$<CONFIG>"
            -ExecutablePath "$<TARGET_FILE:shinsoku>"
            -WindeployQtPath "${SHINSOKU_WINDEPLOYQT}"
            -VcpkgInstalledDir "${SHINSOKU_WINDOWS_VCPKG_INSTALLED_DIR}"
            -OutputDir "${SHINSOKU_PACKAGE_OUTPUT_DIR}"
        DEPENDS shinsoku
        COMMENT "Packaging Windows portable zip"
        VERBATIM
    )
endif()

if(APPLE)
    find_program(SHINSOKU_MACDEPLOYQT NAMES macdeployqt HINTS "${QT_BIN_DIR}" REQUIRED)
    set(SHINSOKU_PACKAGE_OUTPUT_DIR "${CMAKE_BINARY_DIR}/packages")
    set(SHINSOKU_MACOS_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/packaging/macos/Info.plist")
    set(SHINSOKU_MACOS_ENTITLEMENTS "${CMAKE_CURRENT_BINARY_DIR}/packaging/macos/Entitlements.plist")
    configure_file(
        "${CMAKE_SOURCE_DIR}/packaging/macos/Info.plist.in"
        "${SHINSOKU_MACOS_INFO_PLIST}"
        @ONLY
    )
    configure_file(
        "${CMAKE_SOURCE_DIR}/packaging/macos/Entitlements.plist.in"
        "${SHINSOKU_MACOS_ENTITLEMENTS}"
        @ONLY
    )

    add_custom_target(package_macos_dmg
        COMMAND "${CMAKE_SOURCE_DIR}/packaging/macos/package-dmg.sh"
            --app-name "Shinsoku"
            --version "${PROJECT_VERSION}"
            --config "$<CONFIG>"
            --executable "$<TARGET_FILE:shinsoku>"
            --macdeployqt "${SHINSOKU_MACDEPLOYQT}"
            --plist "${SHINSOKU_MACOS_INFO_PLIST}"
            --entitlements "${SHINSOKU_MACOS_ENTITLEMENTS}"
            --icon-svg "${CMAKE_SOURCE_DIR}/resources/icons/square-bolt.svg"
            --output-dir "${SHINSOKU_PACKAGE_OUTPUT_DIR}"
        DEPENDS shinsoku
        COMMENT "Packaging macOS app bundle and DMG"
        VERBATIM
    )
endif()

if(WIN32)
    target_link_libraries(shinsoku PRIVATE bcrypt ole32 uiautomationcore user32)
endif()

if(APPLE)
    find_library(AVFOUNDATION_FRAMEWORK AVFoundation REQUIRED)
    find_library(APPKIT_FRAMEWORK AppKit REQUIRED)
    find_library(APPLICATION_SERVICES_FRAMEWORK ApplicationServices REQUIRED)
    find_library(CARBON_FRAMEWORK Carbon REQUIRED)
    find_library(CORE_MEDIA_FRAMEWORK CoreMedia REQUIRED)
    find_library(SCREEN_CAPTURE_KIT_FRAMEWORK ScreenCaptureKit REQUIRED)
    find_library(AUDIO_TOOLBOX_FRAMEWORK AudioToolbox REQUIRED)
    target_link_libraries(shinsoku PRIVATE
        ${AVFOUNDATION_FRAMEWORK}
        ${APPKIT_FRAMEWORK}
        ${APPLICATION_SERVICES_FRAMEWORK}
        ${AUDIO_TOOLBOX_FRAMEWORK}
        ${CARBON_FRAMEWORK}
        ${CORE_MEDIA_FRAMEWORK}
        ${SCREEN_CAPTURE_KIT_FRAMEWORK}
    )
endif()

if(UNIX AND NOT APPLE)
    target_link_libraries(shinsoku PRIVATE PkgConfig::LIBEVDEV PkgConfig::LIBPULSE PkgConfig::LIBPULSE_SIMPLE)
endif()

if(UNIX AND NOT APPLE AND OHMYTYPELESS_ENABLE_WAYLAND_LAYER_SHELL_HUD)
    if(NOT TARGET Qt6::WaylandClientPrivate)
        find_package(Qt6 QUIET COMPONENTS WaylandClientPrivate)
    endif()
    if(NOT TARGET Qt6::WaylandClientPrivate)
        find_package(Qt6WaylandClient CONFIG REQUIRED)
    endif()
    if(NOT TARGET Qt6::WaylandClientPrivate)
        file(GLOB SHINSOKU_QT_WAYLANDCLIENT_PRIVATE_INCLUDE_CANDIDATES
            "/usr/include/*/qt6/QtWaylandClient/*/QtWaylandClient/private"
            "/usr/include/qt6/QtWaylandClient/*/QtWaylandClient/private"
        )
        list(LENGTH SHINSOKU_QT_WAYLANDCLIENT_PRIVATE_INCLUDE_CANDIDATES SHINSOKU_QT_WAYLANDCLIENT_PRIVATE_INCLUDE_COUNT)
        if(SHINSOKU_QT_WAYLANDCLIENT_PRIVATE_INCLUDE_COUNT EQUAL 0)
            find_package(Qt6WaylandClientPrivate CONFIG REQUIRED)
        else()
            list(GET SHINSOKU_QT_WAYLANDCLIENT_PRIVATE_INCLUDE_CANDIDATES 0 SHINSOKU_QT_WAYLANDCLIENT_PRIVATE_INCLUDE_DIR)
            add_library(shinsoku_qt_waylandclient_private INTERFACE)
            target_link_libraries(shinsoku_qt_waylandclient_private INTERFACE Qt6::WaylandClient)
            target_include_directories(shinsoku_qt_waylandclient_private INTERFACE
                "${SHINSOKU_QT_WAYLANDCLIENT_PRIVATE_INCLUDE_DIR}"
            )
            add_library(Qt6::WaylandClientPrivate ALIAS shinsoku_qt_waylandclient_private)
        endif()
    endif()
    target_link_libraries(shinsoku PRIVATE Qt6::WaylandClientPrivate)
    qt6_generate_wayland_protocol_client_sources(shinsoku
        FILES
            ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/wayland/wlr-layer-shell-unstable-v1.xml
    )
    target_compile_definitions(shinsoku PRIVATE OHMYTYPELESS_HAS_WAYLAND_LAYER_SHELL=1)
endif()

target_compile_options(shinsoku PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/W4 /permissive->
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wall -Wextra -Wpedantic>
)
