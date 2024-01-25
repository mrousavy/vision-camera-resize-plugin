//
// Created by Marc Rousavy on 25.01.24.
//

#pragma once

#include <fbjni/fbjni.h>
#include <jni.h>
#include <fbjni/ByteBuffer.h>

namespace vision {

using namespace facebook;
using namespace jni;

struct JImagePlane : public JavaClass<JImagePlane> {
  static constexpr auto kJavaDescriptor = "Landroid/media/Image$Plane;";

 public:
  jni::local_ref<JByteBuffer> getBuffer() const;
  int getPixelStride() const;
  int getRowStride() const;
};

} // vision

