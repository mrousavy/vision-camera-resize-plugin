package com.visioncameraresizeplugin

import android.util.Log
import com.mrousavy.camera.frameprocessor.Frame
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessor.SharedArray
import com.mrousavy.camera.frameprocessor.VisionCameraProxy
import io.github.crow_misia.libyuv.ArgbBuffer
import io.github.crow_misia.libyuv.FilterMode
import io.github.crow_misia.libyuv.I420Buffer
import io.github.crow_misia.libyuv.asPlane

class ResizePlugin(private val proxy: VisionCameraProxy) : FrameProcessorPlugin() {
    private var _resizeArray: SharedArray? = null
    private var _argbArray: SharedArray? = null
    companion object {
        private const val TAG = "ResizePlugin"
    }

    enum class RGBFormat {
        RGB_8,
        BGR_8,
        ARGB_8,
        RGBA_8,
        BGRA_8,
        ABGR_8;

        val bytesPerPixel: Int
            get() {
                return when (this) {
                    RGB_8, BGR_8 -> 3
                    ARGB_8, RGBA_8, BGRA_8, ABGR_8 -> 4
                }
            }

        companion object {
            fun fromString(string: String): RGBFormat {
                return when (string) {
                    "rgb-uint8" -> RGB_8
                    "argb-uint8" -> ARGB_8
                    else -> throw Error("Invalid PixelFormat! ($string)")
                }
            }
        }
    }

    override fun callback(frame: Frame, params: MutableMap<String, Any>?): Any? {
        if (params == null) {
            throw Error("Options cannot be null!")
        }

        var targetWidth = frame.width
        var targetHeight = frame.height
        var targetFormat = RGBFormat.ARGB_8

        val targetSize = params["size"] as? Map<*, *>
        if (targetSize != null) {
            val targetWidthDouble = targetSize["width"] as? Double
            val targetHeightDouble = targetSize["height"] as? Double
            if (targetWidthDouble != null && targetHeightDouble != null) {
                targetWidth = targetWidthDouble.toInt()
                targetHeight = targetHeightDouble.toInt()
                Log.i(TAG, "Target size: $targetWidth x $targetHeight")
            }
        }

        val formatString = params["pixelFormat"] as? String
        if (formatString != null) {
            targetFormat = RGBFormat.fromString(formatString)
            Log.i(TAG, "Target Format: $targetFormat")
        }

        val image = frame.image
        val y = image.planes[0].asPlane()
        val u = image.planes[1].asPlane()
        val v = image.planes[2].asPlane()
        val buffer = I420Buffer.wrap(y, u, v, image.width, image.height)

        val totalBufferSize = y.buffer.remaining() + u.buffer.remaining() + v.buffer.remaining()
        val yuvBytesPerPixel = totalBufferSize.toDouble() / image.width / image.height
        val resizeSize = (targetWidth * targetHeight * yuvBytesPerPixel).toInt()
        if (_resizeArray == null || _resizeArray!!.byteBuffer.remaining() != resizeSize) {
            Log.i(TAG, "Allocating _resizeArray... (size: $resizeSize)")
            _resizeArray = SharedArray(proxy, SharedArray.Type.Uint8Array, resizeSize)
        }
        val resizeBuffer = I420Buffer.wrap(_resizeArray!!.byteBuffer, targetWidth, targetHeight)

        Log.i(TAG, "Resizing ${frame.width}x${frame.height} Frame to ${targetWidth}x${targetHeight}...")
        buffer.scale(resizeBuffer, FilterMode.BILINEAR)

        val argbSize = image.width * image.height * targetFormat.bytesPerPixel
        if (_argbArray == null || _argbArray!!.byteBuffer.remaining() != argbSize) {
            Log.i(TAG, "Allocating _argbArray... (size: $argbSize)")
            _argbArray = SharedArray(proxy, SharedArray.Type.Uint8Array, argbSize)
        }
        val argbBuffer = ArgbBuffer.wrap(_argbArray!!.byteBuffer, image.width, image.height)
        resizeBuffer.convertTo(argbBuffer)

        return _argbArray
    }

}