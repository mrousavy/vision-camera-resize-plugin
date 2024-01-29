//
// Created by Marc Rousavy on 25.01.24.
//

#include "JImage.h"

#include <fbjni/fbjni.h>
#include <jni.h>

namespace vision {

using namespace facebook;
using namespace jni;

int JImage::getWidth() const {
  auto method = getClass()->getMethod<jint()>("getWidth");
  auto result = method(self());
  return result;
}

int JImage::getHeight() const {
  auto method = getClass()->getMethod<jint()>("getHeight");
  auto result = method(self());
  return result;
}

jni::local_ref<jni::JArrayClass<JImagePlane>> JImage::getPlanes() const {
  auto method = getClass()->getMethod<jni::JArrayClass<JImagePlane>()>("getPlanes");
  auto result = method(self());
  return result;
}

} // namespace vision