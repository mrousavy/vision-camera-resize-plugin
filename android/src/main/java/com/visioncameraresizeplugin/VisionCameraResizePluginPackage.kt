package com.visioncameraresizeplugin

import com.facebook.react.TurboReactPackage
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.NativeModule
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.module.model.ReactModuleInfo
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessor.FrameProcessorPluginRegistry
import java.util.HashMap

class VisionCameraResizePluginPackage : TurboReactPackage() {
  companion object {
    init {
        FrameProcessorPluginRegistry.addFrameProcessorPlugin("resize") { proxy, _ ->
          ResizePlugin(proxy)
        }
    }
  }

  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
    return null
  }

  override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
    return ReactModuleInfoProvider {
      return@ReactModuleInfoProvider emptyMap<String, ReactModuleInfo>()
    }
  }
}
