cmake_minimum_required(VERSION 3.22.1)

project(shinsoku_nativecore LANGUAGES CXX)

add_library(
    shinsoku_nativecore
    SHARED
    native_bridge.cpp
    ../../../../../nativecore/src/c_api.cpp
    ../../../../../nativecore/src/profile_presets.cpp
    ../../../../../nativecore/src/transcript_cleanup.cpp
    ../../../../../nativecore/src/transcript_commit_planner.cpp
    ../../../../../nativecore/src/transform_prompt.cpp
    ../../../../../nativecore/src/runtime_derivation.cpp
)

find_library(log-lib log)

target_compile_features(shinsoku_nativecore PRIVATE cxx_std_20)
target_link_options(
    shinsoku_nativecore
    PRIVATE
    "-Wl,-z,max-page-size=16384"
    "-Wl,-z,common-page-size=16384"
)
target_include_directories(
    shinsoku_nativecore
    PRIVATE
    ../../../../../nativecore/include
)

target_link_libraries(
    shinsoku_nativecore
    ${log-lib}
)
