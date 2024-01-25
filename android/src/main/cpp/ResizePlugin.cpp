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
  jni::local_ref<JByteBuffer> yBuffer = yPlane->getBuffer();
  jni::local_ref<JImagePlane> uPlane = planes->getElement(1);
  jni::local_ref<JByteBuffer> uBuffer = uPlane->getBuffer();
  jni::local_ref<JImagePlane> vPlane = planes->getElement(2);
  jni::local_ref<JByteBuffer> vBuffer = vPlane->getBuffer();

  size_t uvPixelStride = uPlane->getPixelStride();
  if (uPlane->getPixelStride() != vPlane->getPixelStride()) {
    throw std::runtime_error("U and V planes do not have the same pixel stride! Are you sure this is a 4:2:0 YUV format?");
  }

  size_t channels = 4; // ARGB
  size_t channelSize = sizeof(uint8_t);
  uint8_t* destination = (uint8_t*) malloc(width * height * channels * channelSize);

  int result = libyuv::Android420ToARGB(yBuffer->getDirectBytes(), yPlane->getRowStride(),
                                        uBuffer->getDirectBytes(), uPlane->getRowStride(),
                                        vBuffer->getDirectBytes(), vPlane->getRowStride(),
                                        uvPixelStride,
                                        destination, width * channels * channelSize,
                                        width, height);

  if (result != 0) {
    throw std::runtime_error("Failed to convert YUV 4:2:0 to ARGB! Error: " + std::to_string(result));
  }

  free(destination);

  return nullptr;
}

jni::local_ref<ResizePlugin::jhybriddata> ResizePlugin::initHybrid(jni::alias_ref<jhybridobject> javaThis) {
  return makeCxxInstance(javaThis);
}

} // namespace vision
