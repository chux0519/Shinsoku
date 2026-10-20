cmake_minimum_required(VERSION 3.24)

project(Shinsoku VERSION 0.1.0 LANGUAGES C CXX)

include(CTest)
include(GNUInstallDirs)

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
    find_program(WAYLAND_SCANNER_EXECUTABLE NAMES wayland-scanner REQUIRED)
    find_file(OHMYTYPELESS_XDG_SHELL_XML
        NAMES xdg-shell.xml
        PATHS
            /usr/share/wayland-protocols/stable/xdg-shell
            /usr/local/share/wayland-protocols/stable/xdg-shell
        REQUIRED
    )
endif()

option(OHMYTYPELESS_ENABLE_WAYLAND_LAYER_SHELL_HUD "Enable Wayland HUD via in-tree layer-shell backend" ON)
option(SHINSOKU_ENABLE_TRAY_DEBUG "Enable temporary tray debug controls in the main window" OFF)

qt_standard_project_setup()

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
    src/core/runtime_profile.hpp
    src/core/runtime_profile.cpp
    src/core/curl_support.hpp
    src/core/curl_support.cpp
    src/core/history_store.hpp
    src/core/history_store.cpp
    src/core/input/device_adapter_protocol.hpp
    src/core/input/device_adapter_protocol.cpp
    src/core/input/push_audio_source.hpp
    src/core/nearby/nearby_connection.hpp
    src/core/nearby/nearby_connection.cpp
    src/core/nearby/nearby_protocol.hpp
    src/core/nearby/nearby_protocol.cpp
    src/core/nearby/nearby_tls_identity.hpp
    src/core/nearby/nearby_tls_identity.cpp
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
    src/platform/input_target_context.hpp
    src/platform/input_target_context.cpp
    src/platform/miniaudio_audio_capture_service.hpp
    src/platform/miniaudio_audio_capture_service.cpp
    src/platform/network/nearby_websocket_server.hpp
    src/platform/network/nearby_websocket_server.cpp
    src/platform/network/nearby_discovery_publisher.hpp
    src/platform/network/nearby_runtime.hpp
    src/platform/network/nearby_runtime.cpp
    src/platform/network/push_audio_capture_service.hpp
    src/platform/network/push_audio_capture_service.cpp
    src/platform/process/device_adapter_runtime.hpp
    src/platform/process/device_adapter_runtime.cpp
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
target_compile_definitions(shinsoku PRIVATE SHINSOKU_VERSION="${PROJECT_VERSION}")

add_executable(shinsoku-history
    src/cli/history_cli.cpp
    src/core/app_config.hpp
    src/core/app_config.cpp
    src/core/app_state.hpp
    src/core/history_store.hpp
    src/core/history_store.cpp
    src/core/history_export.hpp
    src/core/history_export.cpp
    src/platform/hotkey_names.hpp
    src/platform/hotkey_names.cpp
)

target_include_directories(shinsoku-history PRIVATE src)
target_link_libraries(shinsoku-history PRIVATE
    Qt6::Core
    nlohmann_json::nlohmann_json
    unofficial::sqlite3::sqlite3
)

install(TARGETS shinsoku-history
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

add_executable(shinsoku-history-mcp
    src/cli/history_mcp.cpp
    src/core/app_config.hpp
    src/core/app_config.cpp
    src/core/app_state.hpp
    src/core/history_export.hpp
    src/core/history_export.cpp
    src/core/history_mcp_server.hpp
    src/core/history_mcp_server.cpp
    src/core/history_store.hpp
    src/core/history_store.cpp
    src/platform/hotkey_names.hpp
    src/platform/hotkey_names.cpp
)
target_include_directories(shinsoku-history-mcp PRIVATE src)
target_link_libraries(shinsoku-history-mcp PRIVATE
    Qt6::Core
    nlohmann_json::nlohmann_json
    unofficial::sqlite3::sqlite3
)
install(TARGETS shinsoku-history-mcp
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(DIRECTORY skills/read-shinsoku-history
    DESTINATION ${CMAKE_INSTALL_DATADIR}/shinsoku/skills
)

add_executable(shinsoku-adapter-check
    src/cli/device_adapter_check.cpp
    src/core/input/device_adapter_protocol.hpp
    src/core/input/device_adapter_protocol.cpp
)
target_include_directories(shinsoku-adapter-check PRIVATE src)
target_link_libraries(shinsoku-adapter-check PRIVATE
    MbedTLS::mbedcrypto
    nlohmann_json::nlohmann_json
)
install(TARGETS shinsoku-adapter-check
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(FILES examples/device-adapters/synthetic_adapter.py
    DESTINATION ${CMAKE_INSTALL_DATADIR}/shinsoku/device-adapters/examples
)

if(BUILD_TESTING)
    add_executable(history_store_tests
        tests/history_store_test.cpp
        src/core/app_state.hpp
        src/core/history_store.hpp
        src/core/history_store.cpp
        src/platform/input_target_context.hpp
        src/platform/input_target_context.cpp
    )
    target_include_directories(history_store_tests PRIVATE src)
    target_link_libraries(history_store_tests PRIVATE
        Qt6::Core
        nlohmann_json::nlohmann_json
        unofficial::sqlite3::sqlite3
    )
    add_test(NAME history_store_tests COMMAND history_store_tests)

    add_executable(history_window_tests
        tests/history_window_test.cpp
        src/core/app_state.hpp
        src/ui/history_window.hpp
        src/ui/history_window.cpp
    )
    target_include_directories(history_window_tests PRIVATE src)
    target_link_libraries(history_window_tests PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Widgets
        nlohmann_json::nlohmann_json
    )
    add_test(NAME history_window_tests COMMAND history_window_tests)

    add_executable(app_profile_tests
        tests/app_profile_test.cpp
        src/core/app_config.hpp
        src/core/app_config.cpp
        src/core/runtime_profile.hpp
        src/core/runtime_profile.cpp
        src/platform/hotkey_names.hpp
        src/platform/hotkey_names.cpp
    )
    target_include_directories(app_profile_tests PRIVATE src)
    target_link_libraries(app_profile_tests PRIVATE
        Qt6::Core
        nlohmann_json::nlohmann_json
    )
    add_test(NAME app_profile_tests COMMAND app_profile_tests)

    add_executable(settings_window_tests
        tests/settings_window_test.cpp
        src/core/app_config.hpp
        src/core/app_config.cpp
        src/core/runtime_profile.hpp
        src/core/runtime_profile.cpp
        src/platform/hotkey_names.hpp
        src/platform/hotkey_names.cpp
        src/ui/settings_window.hpp
        src/ui/settings_window.cpp
    )
    target_include_directories(settings_window_tests PRIVATE src)
    target_link_libraries(settings_window_tests PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Widgets
        nlohmann_json::nlohmann_json
    )
    add_test(NAME settings_window_tests COMMAND settings_window_tests)

    add_executable(history_mcp_server_tests
        tests/history_mcp_server_test.cpp
        src/core/app_state.hpp
        src/core/history_export.hpp
        src/core/history_export.cpp
        src/core/history_mcp_server.hpp
        src/core/history_mcp_server.cpp
        src/core/history_store.hpp
        src/core/history_store.cpp
    )
    target_include_directories(history_mcp_server_tests PRIVATE src)
    target_link_libraries(history_mcp_server_tests PRIVATE
        Qt6::Core
        nlohmann_json::nlohmann_json
        unofficial::sqlite3::sqlite3
    )
    add_test(NAME history_mcp_server_tests COMMAND history_mcp_server_tests)

    add_executable(device_adapter_protocol_tests
        tests/device_adapter_protocol_test.cpp
        src/core/input/device_adapter_protocol.hpp
        src/core/input/device_adapter_protocol.cpp
    )
    target_include_directories(device_adapter_protocol_tests PRIVATE src)
    target_link_libraries(device_adapter_protocol_tests PRIVATE
        MbedTLS::mbedcrypto
        nlohmann_json::nlohmann_json
    )
    add_test(NAME device_adapter_protocol_tests COMMAND device_adapter_protocol_tests)
    add_test(NAME device_adapter_check_trace
        COMMAND shinsoku-adapter-check
            --trace ${CMAKE_SOURCE_DIR}/tests/fixtures/device_adapter_valid.jsonl
            --require-audio
    )

    add_executable(device_adapter_runtime_fixture
        tests/support/device_adapter_runtime_fixture.cpp
    )
    target_link_libraries(device_adapter_runtime_fixture PRIVATE
        nlohmann_json::nlohmann_json
    )

    add_executable(device_adapter_runtime_tests
        tests/device_adapter_runtime_test.cpp
        src/core/input/device_adapter_protocol.hpp
        src/core/input/device_adapter_protocol.cpp
        src/core/input/push_audio_source.hpp
        src/platform/process/device_adapter_runtime.hpp
        src/platform/process/device_adapter_runtime.cpp
    )
    target_include_directories(device_adapter_runtime_tests PRIVATE src)
    target_link_libraries(device_adapter_runtime_tests PRIVATE
        Qt6::Core
        MbedTLS::mbedcrypto
        nlohmann_json::nlohmann_json
    )
    add_test(NAME device_adapter_runtime_tests
        COMMAND device_adapter_runtime_tests $<TARGET_FILE:device_adapter_runtime_fixture>
    )

    add_executable(nearby_protocol_tests
        tests/nearby_protocol_test.cpp
        src/core/input/push_audio_source.hpp
        src/core/nearby/nearby_protocol.hpp
        src/core/nearby/nearby_protocol.cpp
    )
    target_include_directories(nearby_protocol_tests PRIVATE src)
    target_link_libraries(nearby_protocol_tests PRIVATE
        MbedTLS::mbedcrypto
        nlohmann_json::nlohmann_json
    )
    add_test(NAME nearby_protocol_tests COMMAND nearby_protocol_tests)

    add_executable(nearby_websocket_server_tests
        tests/nearby_websocket_server_test.cpp
        src/core/input/push_audio_source.hpp
        src/core/nearby/nearby_connection.hpp
        src/core/nearby/nearby_connection.cpp
        src/core/nearby/nearby_protocol.hpp
        src/core/nearby/nearby_protocol.cpp
        src/core/nearby/nearby_tls_identity.hpp
        src/core/nearby/nearby_tls_identity.cpp
        src/platform/network/nearby_websocket_server.hpp
        src/platform/network/nearby_websocket_server.cpp
    )
    target_include_directories(nearby_websocket_server_tests PRIVATE src)
    target_link_libraries(nearby_websocket_server_tests PRIVATE
        ixwebsocket::ixwebsocket
        MbedTLS::mbedx509
        MbedTLS::mbedcrypto
        nlohmann_json::nlohmann_json
    )
    add_test(NAME nearby_websocket_server_tests COMMAND nearby_websocket_server_tests)

    add_executable(push_audio_capture_service_tests
        tests/push_audio_capture_service_test.cpp
        src/core/input/push_audio_source.hpp
        src/core/nearby/nearby_protocol.hpp
        src/core/nearby/nearby_protocol.cpp
        src/platform/audio_capture_service.hpp
        src/platform/network/push_audio_capture_service.hpp
        src/platform/network/push_audio_capture_service.cpp
    )
    target_include_directories(push_audio_capture_service_tests PRIVATE src)
    target_link_libraries(push_audio_capture_service_tests PRIVATE
        MbedTLS::mbedcrypto
        nlohmann_json::nlohmann_json
    )
    add_test(NAME push_audio_capture_service_tests COMMAND push_audio_capture_service_tests)

    add_executable(nearby_tls_identity_tests
        tests/nearby_tls_identity_test.cpp
        src/core/nearby/nearby_tls_identity.hpp
        src/core/nearby/nearby_tls_identity.cpp
    )
    target_include_directories(nearby_tls_identity_tests PRIVATE src)
    target_link_libraries(nearby_tls_identity_tests PRIVATE
        MbedTLS::mbedx509
        MbedTLS::mbedcrypto
        nlohmann_json::nlohmann_json
    )
    add_test(NAME nearby_tls_identity_tests COMMAND nearby_tls_identity_tests)

    add_executable(nearby_runtime_tests
        tests/nearby_runtime_test.cpp
        src/core/input/push_audio_source.hpp
        src/core/nearby/nearby_connection.hpp
        src/core/nearby/nearby_connection.cpp
        src/core/nearby/nearby_protocol.hpp
        src/core/nearby/nearby_protocol.cpp
        src/core/nearby/nearby_tls_identity.hpp
        src/core/nearby/nearby_tls_identity.cpp
        src/platform/network/nearby_discovery_publisher.hpp
        src/platform/network/nearby_runtime.hpp
        src/platform/network/nearby_runtime.cpp
        src/platform/network/nearby_websocket_server.hpp
        src/platform/network/nearby_websocket_server.cpp
    )
    target_include_directories(nearby_runtime_tests PRIVATE src)
    target_link_libraries(nearby_runtime_tests PRIVATE
        ixwebsocket::ixwebsocket
        MbedTLS::mbedx509
        MbedTLS::mbedcrypto
        nlohmann_json::nlohmann_json
    )
    add_test(NAME nearby_runtime_tests COMMAND nearby_runtime_tests)

    add_executable(nearby_server_fixture
        tests/support/nearby_server_fixture.cpp
        src/core/input/push_audio_source.hpp
        src/core/nearby/nearby_connection.hpp
        src/core/nearby/nearby_connection.cpp
        src/core/nearby/nearby_protocol.hpp
        src/core/nearby/nearby_protocol.cpp
        src/core/nearby/nearby_tls_identity.hpp
        src/core/nearby/nearby_tls_identity.cpp
        src/platform/network/nearby_websocket_server.hpp
        src/platform/network/nearby_websocket_server.cpp
    )
    target_include_directories(nearby_server_fixture PRIVATE src)
    target_link_libraries(nearby_server_fixture PRIVATE
        ixwebsocket::ixwebsocket
        MbedTLS::mbedx509
        MbedTLS::mbedcrypto
        nlohmann_json::nlohmann_json
    )

    if(APPLE)
        add_executable(macos_bonjour_publisher_tests
            tests/macos_bonjour_publisher_test.cpp
            src/platform/network/nearby_discovery_publisher.hpp
            src/platform/macos/macos_bonjour_publisher.hpp
            src/platform/macos/macos_bonjour_publisher.cpp
        )
        target_include_directories(macos_bonjour_publisher_tests PRIVATE src)
        add_test(NAME macos_bonjour_publisher_tests COMMAND macos_bonjour_publisher_tests)
    endif()

    if(APPLE)
        set_tests_properties(history_window_tests settings_window_tests PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=cocoa")
    elseif(UNIX)
        set_tests_properties(history_window_tests settings_window_tests PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
    endif()
endif()

if(WIN32)
    set_target_properties(shinsoku PROPERTIES WIN32_EXECUTABLE TRUE)
endif()

install(TARGETS shinsoku
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(WIN32)
    target_sources(shinsoku PRIVATE
        resources/windows/app.rc
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
        src/platform/macos/macos_bonjour_publisher.hpp
        src/platform/macos/macos_bonjour_publisher.cpp
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
    find_file(SHINSOKU_QWINDOWS_PLUGIN_RELEASE
        NAMES qwindows.dll
        HINTS
            "${SHINSOKU_WINDOWS_VCPKG_INSTALLED_DIR}/Qt6/plugins/platforms"
            "${QT_INSTALL_PREFIX}/plugins/platforms"
            "${QT_HOST_PREFIX}/plugins/platforms"
            "${QT_VCPKG_PREFIX}/Qt6/plugins/platforms"
        REQUIRED
    )
    find_file(SHINSOKU_QWINDOWS_PLUGIN_DEBUG
        NAMES qwindowsd.dll qwindows.dll
        HINTS
            "${SHINSOKU_WINDOWS_VCPKG_INSTALLED_DIR}/debug/Qt6/plugins/platforms"
            "${SHINSOKU_WINDOWS_VCPKG_INSTALLED_DIR}/Qt6/plugins/platforms"
            "${QT_INSTALL_PREFIX}/debug/Qt6/plugins/platforms"
            "${QT_INSTALL_PREFIX}/plugins/platforms"
            "${QT_HOST_PREFIX}/plugins/platforms"
            "${QT_VCPKG_PREFIX}/debug/Qt6/plugins/platforms"
            "${QT_VCPKG_PREFIX}/Qt6/plugins/platforms"
        REQUIRED
    )
    set(SHINSOKU_QWINDOWS_PLUGIN
        "$<$<CONFIG:Debug>:${SHINSOKU_QWINDOWS_PLUGIN_DEBUG}>$<$<NOT:$<CONFIG:Debug>>:${SHINSOKU_QWINDOWS_PLUGIN_RELEASE}>"
    )
    add_custom_command(TARGET shinsoku POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:shinsoku>/platforms"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${SHINSOKU_QWINDOWS_PLUGIN}
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
            -HistoryCliPath "$<TARGET_FILE:shinsoku-history>"
            -HistoryMcpPath "$<TARGET_FILE:shinsoku-history-mcp>"
            -HistorySkillPath "${CMAKE_SOURCE_DIR}/skills/read-shinsoku-history"
            -AdapterCheckPath "$<TARGET_FILE:shinsoku-adapter-check>"
            -AdapterExamplePath "${CMAKE_SOURCE_DIR}/examples/device-adapters/synthetic_adapter.py"
            -WindeployQtPath "${SHINSOKU_WINDEPLOYQT}"
            -VcpkgInstalledDir "${SHINSOKU_WINDOWS_VCPKG_INSTALLED_DIR}"
            -OutputDir "${SHINSOKU_PACKAGE_OUTPUT_DIR}"
        DEPENDS shinsoku shinsoku-history shinsoku-history-mcp shinsoku-adapter-check
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
            --history-cli "$<TARGET_FILE:shinsoku-history>"
            --history-mcp "$<TARGET_FILE:shinsoku-history-mcp>"
            --history-skill "${CMAKE_SOURCE_DIR}/skills/read-shinsoku-history"
            --adapter-check "$<TARGET_FILE:shinsoku-adapter-check>"
            --adapter-example "${CMAKE_SOURCE_DIR}/examples/device-adapters/synthetic_adapter.py"
            --macdeployqt "${SHINSOKU_MACDEPLOYQT}"
            --plist "${SHINSOKU_MACOS_INFO_PLIST}"
            --entitlements "${SHINSOKU_MACOS_ENTITLEMENTS}"
            --icon-svg "${CMAKE_SOURCE_DIR}/resources/icons/square-bolt.svg"
            --output-dir "${SHINSOKU_PACKAGE_OUTPUT_DIR}"
        DEPENDS shinsoku shinsoku-history shinsoku-history-mcp shinsoku-adapter-check
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
    set(OHMYTYPELESS_XDG_SHELL_HEADER "${CMAKE_CURRENT_BINARY_DIR}/wayland-xdg-shell-client-protocol.h")
    set(OHMYTYPELESS_XDG_SHELL_CODE "${CMAKE_CURRENT_BINARY_DIR}/wayland-xdg-shell-protocol.c")
    add_custom_command(
        OUTPUT "${OHMYTYPELESS_XDG_SHELL_HEADER}"
        COMMAND "${WAYLAND_SCANNER_EXECUTABLE}" client-header "${OHMYTYPELESS_XDG_SHELL_XML}" "${OHMYTYPELESS_XDG_SHELL_HEADER}"
        DEPENDS "${OHMYTYPELESS_XDG_SHELL_XML}"
        VERBATIM
    )
    add_custom_command(
        OUTPUT "${OHMYTYPELESS_XDG_SHELL_CODE}"
        COMMAND "${WAYLAND_SCANNER_EXECUTABLE}" public-code "${OHMYTYPELESS_XDG_SHELL_XML}" "${OHMYTYPELESS_XDG_SHELL_CODE}"
        DEPENDS "${OHMYTYPELESS_XDG_SHELL_XML}"
        VERBATIM
    )
    target_sources(shinsoku PRIVATE
        "${OHMYTYPELESS_XDG_SHELL_HEADER}"
        "${OHMYTYPELESS_XDG_SHELL_CODE}"
    )
    find_package(Qt6WaylandClientPrivate CONFIG REQUIRED)
    target_link_libraries(shinsoku PRIVATE Qt6::WaylandClientPrivate)
    qt6_generate_wayland_protocol_client_sources(shinsoku
        PRIVATE_CODE
        FILES
            ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/wayland/wlr-layer-shell-unstable-v1.xml
    )
    target_compile_definitions(shinsoku PRIVATE OHMYTYPELESS_HAS_WAYLAND_LAYER_SHELL=1)
endif()

if(UNIX AND NOT APPLE)
    qt_generate_deploy_app_script(
        TARGET shinsoku
        OUTPUT_SCRIPT SHINSOKU_LINUX_DEPLOY_QT_SCRIPT
        NO_UNSUPPORTED_PLATFORM_ERROR
        INCLUDE_PLUGIN_TYPES platforms
    )
    install(SCRIPT ${SHINSOKU_LINUX_DEPLOY_QT_SCRIPT})
endif()

target_compile_options(shinsoku PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/W4 /permissive->
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wall -Wextra -Wpedantic>
)
