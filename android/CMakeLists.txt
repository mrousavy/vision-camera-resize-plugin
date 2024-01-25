project(VisionCameraResizePlugin)
cmake_minimum_required(VERSION 3.9.0)

set (PACKAGE_NAME "VisionCameraResizePlugin")
set (BUILD_DIR ${CMAKE_SOURCE_DIR}/build)
set (CMAKE_VERBOSE_MAKEFILE ON)
set (CMAKE_CXX_STANDARD 17)

# Third party libraries (Prefabs)
find_package(fbjni REQUIRED CONFIG)
find_library(LOG_LIB log)

# libyuv
add_subdirectory(libyuv)

add_library(${PACKAGE_NAME}            SHARED
            src/main/cpp/ResizePlugin.cpp
            src/main/cpp/JImage.cpp
            src/main/cpp/JImagePlane.cpp
            src/main/cpp/VisionCameraResizePlugin.cpp
)

# Specifies a path to native header files.
target_include_directories(
            ${PACKAGE_NAME}            PRIVATE
            src/main/cpp
            libyuv/include
)

target_link_libraries(
        ${PACKAGE_NAME}
        ${LOG_LIB}                          # <-- Logcat logger
        android                             # <-- Android JNI core
        fbjni::fbjni                        # <-- fbjni
        yuv                                 # <-- libyuv
)
