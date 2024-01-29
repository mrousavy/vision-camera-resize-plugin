//
// Created by Marc Rousavy on 25.01.24.
//

#include "JImagePlane.h"

namespace vision {

using namespace facebook;
using namespace jni;

int JImagePlane::getPixelStride() const {
  auto method = getClass()->getMethod<jint()>("getPixelStride");
  auto result = method(self());
  return result;
}

int JImagePlane::getRowStride() const {
  auto method = getClass()->getMethod<jint()>("getRowStride");
  auto result = method(self());
  return result;
}

jni::local_ref<JByteBuffer> JImagePlane::getBuffer() const {
  auto method = getClass()->getMethod<JByteBuffer()>("getBuffer");
  auto result = method(self());
  return result;
}

} // namespace vision