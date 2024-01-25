package com.visioncameraresizeplugin

import android.media.Image
import android.util.Log
import androidx.annotation.Keep
import com.facebook.jni.HybridData
import com.facebook.jni.annotations.DoNotStrip
import com.mrousavy.camera.frameprocessor.Frame
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessor.SharedArray
import com.mrousavy.camera.frameprocessor.VisionCameraProxy
import java.nio.ByteBuffer

class ResizePlugin(private val proxy: VisionCameraProxy) : FrameProcessorPlugin() {
    @DoNotStrip
    @Keep
    private val mHybridData: HybridData

    companion object {
        private const val TAG = "ResizePlugin"

        init {
            System.loadLibrary("VisionCameraResizePlugin")
        }
    }

    init {
        mHybridData = initHybrid()
    }

    private external fun initHybrid(): HybridData
    private external fun resize(image: Image): ByteBuffer

    override fun callback(frame: Frame, params: MutableMap<String, Any>?): Any {
        if (params == null) {
            throw Error("Options cannot be null!")
        }

        var targetWidth = frame.width
        var targetHeight = frame.height
        var targetX = 0
        var targetY = 0

        val targetSize = params["size"] as? Map<*, *>
        if (targetSize != null) {
            val targetWidthDouble = targetSize["width"] as? Double
            val targetHeightDouble = targetSize["height"] as? Double
            val targetXDouble = targetSize["x"] as? Double
            val targetYDouble = targetSize["y"] as? Double
            if (targetWidthDouble != null && targetHeightDouble != null) {
                targetWidth = targetWidthDouble.toInt()
                targetHeight = targetHeightDouble.toInt()
                if (targetXDouble != null && targetYDouble != null) {
                    targetX = targetXDouble.toInt()
                    targetY = targetYDouble.toInt()
                } else {
                    // by default, do a center crop
                    targetX = (frame.width / 2) - (targetWidth / 2)
                    targetY = (frame.height / 2) - (targetHeight / 2)
                }
                Log.i(TAG, "Target size: $targetWidth x $targetHeight")
            }
        }

        val resized = resize(frame.image)
        return SharedArray(proxy, resized)
    }
}
