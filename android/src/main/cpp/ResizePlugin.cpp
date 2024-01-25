//
// Created by Marc Rousavy on 25.01.24
//

#include "ResizePlugin.h"
#include <android/log.h>
#include <fbjni/fbjni.h>
#include <jni.h>
#include "libyuv.h"
#include <media/NdkImage.h>

namespace vision {

using namespace facebook;

void ResizePlugin::registerNatives() {
  registerHybrid({
      makeNativeMethod("initHybrid", ResizePlugin::initHybrid),
      makeNativeMethod("resize", ResizePlugin::resize),
  });
}

ResizePlugin::ResizePlugin(const jni::alias_ref<jhybridobject>& javaThis) {
  _javaThis = jni::make_global(javaThis);
}

jni::local_ref<jni::JByteBuffer> ResizePlugin::resize(jni::alias_ref<JImage> image) {
  int width = image->getWidth();
  int height = image->getHeight();
  jni::local_ref<JArrayClass<JImagePlane>> planes = image->getPlanes();

  jni::local_ref<JImagePlane> yPlane = planes->getElement(0);
  jni::local_ref<JImagePlane> uPlane = planes->getElement(1);
  jni::local_ref<JImagePlane> vPlane = planes->getElement(2);
  // libyuv::Android420ToABGR()



  return nullptr;
}

jni::local_ref<ResizePlugin::jhybriddata> ResizePlugin::initHybrid(jni::alias_ref<jhybridobject> javaThis) {
  return makeCxxInstance(javaThis);
}

} // namespace vision
