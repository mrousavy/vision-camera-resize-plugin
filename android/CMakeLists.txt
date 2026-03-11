project(VisionCameraResizePlugin)
cmake_minimum_required(VERSION 3.9.0)

set(PACKAGE_NAME VisionCameraResizePlugin)
set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_CXX_STANDARD 20)

add_library(${PACKAGE_NAME} SHARED
  src/main/cpp/cpp-adapter.cpp
  src/main/cpp/ResizeProcessor.cpp
  src/main/cpp/JImage.cpp
  src/main/cpp/JImagePlane.cpp
)

add_subdirectory(../libyuv libyuv)

include(${CMAKE_SOURCE_DIR}/../nitrogen/generated/android/VisionCameraResizePlugin+autolinking.cmake)

include_directories(
  "src/main/cpp"
  "../libyuv/include"
)

find_library(LOG_LIB log)
find_package(react-native-vision-camera REQUIRED CONFIG)

target_link_libraries(
  ${PACKAGE_NAME}
  ${LOG_LIB}
  android
  react-native-vision-camera::VisionCamera
  yuv
)
