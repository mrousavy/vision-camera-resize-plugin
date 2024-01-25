//
// Created by Marc Rousavy on 25.01.24
//

#pragma once

#include <fbjni/fbjni.h>
#include <jni.h>
#include <memory>
#include <string>

namespace vision {

using namespace facebook;

struct ResizePlugin : public jni::HybridClass<ResizePlugin> {
public:
  static auto constexpr kJavaDescriptor = "Lcom/visioncameraresizeplugin/ResizePlugin;";
  static void registerNatives();

private:
  explicit ResizePlugin(const jni::alias_ref<jhybridobject>& javaThis);

private:
  friend HybridBase;
  jni::global_ref<javaobject> _javaThis;

  static jni::local_ref<jhybriddata> initHybrid(jni::alias_ref<jhybridobject> javaThis);
};

} // namespace vision
