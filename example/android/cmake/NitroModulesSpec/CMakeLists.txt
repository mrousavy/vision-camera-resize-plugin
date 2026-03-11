cmake_minimum_required(VERSION 3.13)
set(CMAKE_VERBOSE_MAKEFILE on)

project(NitroModulesSpecStub)

# react-native-nitro-modules exposes a ReactPackage, but it doesn't ship a
# codegen JNI target. RN 0.84's app CMake autolinking still expects one when a
# dependency advertises a libraryName, so provide a minimal codegen-shaped stub.
add_library(react_codegen_NitroModulesSpec OBJECT NitroModulesSpec.cpp)

target_include_directories(react_codegen_NitroModulesSpec PUBLIC .)

target_link_libraries(
  react_codegen_NitroModulesSpec
  fbjni
  jsi
  reactnative
)

target_compile_reactnative_options(react_codegen_NitroModulesSpec PRIVATE)
