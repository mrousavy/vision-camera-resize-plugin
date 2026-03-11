#include <fbjni/fbjni.h>
#include <jni.h>

#include "ResizeProcessor.h"
#include "VisionCameraResizePluginOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return facebook::jni::initialize(vm, []() {
    margelo::nitro::visioncameraresizeplugin::registerAllNatives();
    vision::ResizeProcessor::registerNatives();
  });
}
