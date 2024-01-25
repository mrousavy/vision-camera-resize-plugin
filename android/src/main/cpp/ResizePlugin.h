//
// Created by Marc Rousavy on 25.01.24
//

#pragma once

#include <fbjni/fbjni.h>
#include <fbjni/ByteBuffer.h>
#include <jni.h>
#include <memory>
#include <string>

#include "JImage.h"

namespace vision {

using namespace facebook;

enum PixelFormat {
  RGB,
  BGR,
  ARGB,
  RGBA,
  BGRA,
  ABGR
};

enum DataType {
  UINT8,
  FLOAT32
};

struct ResizePlugin : public jni::HybridClass<ResizePlugin> {
public:
  static auto constexpr kJavaDescriptor = "Lcom/visioncameraresizeplugin/ResizePlugin;";
  static void registerNatives();

private:
  explicit ResizePlugin(const jni::alias_ref<jhybridobject>& javaThis);

  jni::alias_ref<jni::JByteBuffer> resize(jni::alias_ref<JImage> image,
                                          int cropX, int cropY,
                                          int targetWidth, int targetHeight,
                                          int /* PixelFormat */ pixelFormat, int /* DataType */ dataType);

private:
  static auto constexpr TAG = "ResizePlugin";
  friend HybridBase;
  jni::global_ref<javaobject> _javaThis;
  jni::global_ref<JByteBuffer> _argbBuffer;

  static jni::local_ref<jhybriddata> initHybrid(jni::alias_ref<jhybridobject> javaThis);
};

} // namespace vision
