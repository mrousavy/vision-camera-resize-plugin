cmake_minimum_required(VERSION 3.4.1)
project(VisionCameraResizePlugin)

set (CMAKE_VERBOSE_MAKEFILE ON)
set (CMAKE_CXX_STANDARD 11)

add_library(react-native-vision-camera-resize-plugin            SHARED
            ../cpp/react-native-vision-camera-resize-plugin.cpp
            cpp-adapter.cpp
)

# Specifies a path to native header files.
include_directories(
            ../cpp
)
