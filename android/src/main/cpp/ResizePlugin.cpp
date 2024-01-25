//
// Created by Marc Rousavy on 25.01.24
//

#include "ResizePlugin.h"
#include <android/log.h>
#include <fbjni/fbjni.h>
#include <jni.h>

namespace vision {

using namespace facebook;

void ResizePlugin::registerNatives() {
  registerHybrid({
      makeNativeMethod("initHybrid", ResizePlugin::initHybrid),
  });
}

jni::local_ref<ResizePlugin::jhybriddata> ResizePlugin::initHybrid(jni::alias_ref<jhybridobject> javaThis) {
  return makeCxxInstance(javaThis);
}

} // namespace vision
