project(VisionCameraResizePlugin)
cmake_minimum_required(VERSION 3.4.1)

set (PACKAGE_NAME "VisionCameraResizePlugin")
set (CMAKE_VERBOSE_MAKEFILE ON)
set (CMAKE_CXX_STANDARD 17)

# Third party libraries (Prefabs)
find_package(fbjni REQUIRED CONFIG)
find_library(LOG_LIB log)

add_library(${PACKAGE_NAME}            SHARED
            src/main/cpp/ResizePlugin.cpp
            src/main/cpp/VisionCameraResizePlugin.cpp
)

# Specifies a path to native header files.
target_include_directories(
            ${PACKAGE_NAME}            PRIVATE
            src/main/cpp
)

target_link_libraries(
        ${PACKAGE_NAME}
        ${LOG_LIB}                          # <-- Logcat logger
        android                             # <-- Android JNI core
        fbjni::fbjni                        # <-- fbjni
)
