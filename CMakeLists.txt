cmake_minimum_required(VERSION 3.24)

project(OhMyTypeless VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Concurrent Core Gui Widgets)
find_package(CURL REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(unofficial-sqlite3 CONFIG REQUIRED)
find_path(MINIAUDIO_INCLUDE_DIRS miniaudio.h REQUIRED)

qt_standard_project_setup()

qt_add_executable(ohmytypeless
    src/main.cpp
    src/core/app_config.hpp
    src/core/app_config.cpp
    src/core/app_state.hpp
    src/core/audio_recorder.hpp
    src/core/audio_recorder.cpp
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
    src/core/text_refiner.hpp
    src/core/text_refiner.cpp
    src/core/wav_encoder.hpp
    src/core/wav_encoder.cpp
    src/platform/clipboard_service.hpp
    src/platform/global_hotkey.hpp
    src/platform/hud_presenter.hpp
    src/platform/qt/qt_clipboard_service.hpp
    src/platform/qt/qt_clipboard_service.cpp
    src/platform/qt/qt_global_hotkey.hpp
    src/platform/qt/qt_global_hotkey.cpp
    src/platform/qt/qt_hud_presenter.hpp
    src/platform/qt/qt_hud_presenter.cpp
    src/ui/main_window.hpp
    src/ui/main_window.cpp
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
    )
endif()

target_include_directories(ohmytypeless PRIVATE src ${MINIAUDIO_INCLUDE_DIRS})

target_link_libraries(ohmytypeless PRIVATE
    CURL::libcurl
    Qt6::Concurrent
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    nlohmann_json::nlohmann_json
    unofficial::sqlite3::sqlite3
)

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
    target_link_libraries(ohmytypeless PRIVATE user32)
endif()

target_compile_options(ohmytypeless PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/W4 /permissive->
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wall -Wextra -Wpedantic>
)
