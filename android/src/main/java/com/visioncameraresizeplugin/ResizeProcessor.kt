package com.margelo.nitro.visioncameraresizeplugin

import android.media.Image
import androidx.annotation.Keep
import com.facebook.jni.HybridData
import com.facebook.proguard.annotations.DoNotStrip
import java.nio.ByteBuffer

@Suppress("KotlinJniMissingFunction")
@DoNotStrip
@Keep
class ResizeProcessor {
  @DoNotStrip
  @Keep
  private val mHybridData: HybridData

  companion object {
    init {
      System.loadLibrary("VisionCameraResizePlugin")
    }
  }

  init {
    mHybridData = initHybrid()
  }

  private external fun initHybrid(): HybridData

  external fun resize(
    image: Image,
    cropX: Int,
    cropY: Int,
    cropWidth: Int,
    cropHeight: Int,
    scaleWidth: Int,
    scaleHeight: Int,
    rotation: Int,
    mirror: Boolean,
    pixelFormat: Int,
    dataType: Int,
  ): ByteBuffer
}
