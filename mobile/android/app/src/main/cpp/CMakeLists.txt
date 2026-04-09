cmake_minimum_required(VERSION 3.22.1)

project(shinsoku_nativecore LANGUAGES CXX)

add_library(
    shinsoku_nativecore
    SHARED
    native_transcript_cleanup.cpp
)

find_library(log-lib log)

target_compile_features(shinsoku_nativecore PRIVATE cxx_std_20)

target_link_libraries(
    shinsoku_nativecore
    ${log-lib}
)
