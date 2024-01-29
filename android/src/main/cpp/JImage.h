//
// Created by Marc Rousavy on 25.01.24.
//

#pragma once

#include "JImagePlane.h"
#include <fbjni/fbjni.h>
#include <jni.h>

namespace vision {

using namespace facebook;
using namespace jni;

struct JImage : public JavaClass<JImage> {
  static constexpr auto kJavaDescriptor = "Landroid/media/Image;";

public:
  int getWidth() const;
  int getHeight() const;
  jni::local_ref<jni::JArrayClass<JImagePlane>> getPlanes() const;
};

} // namespace vision
