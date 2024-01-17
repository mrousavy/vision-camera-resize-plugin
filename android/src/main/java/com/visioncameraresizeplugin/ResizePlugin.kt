package com.visioncameraresizeplugin

import android.graphics.ImageFormat
import android.util.Log
import com.mrousavy.camera.frameprocessor.Frame
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessor.SharedArray
import com.mrousavy.camera.frameprocessor.VisionCameraProxy
import io.github.crow_misia.libyuv.AbgrBuffer
import io.github.crow_misia.libyuv.AbstractBuffer
import io.github.crow_misia.libyuv.ArgbBuffer
import io.github.crow_misia.libyuv.BgraBuffer
import io.github.crow_misia.libyuv.FilterMode
import io.github.crow_misia.libyuv.I420Buffer
import io.github.crow_misia.libyuv.Plane
import io.github.crow_misia.libyuv.Rgb24Buffer
import io.github.crow_misia.libyuv.RgbaBuffer
import io.github.crow_misia.libyuv.ext.ImageExt.toI420Buffer
import java.nio.ByteBuffer
import kotlin.math.roundToInt

val AbstractBuffer.totalSize: Int
    get() {
        return planes.sumOf { it.buffer.limit() }
    }

class ResizePlugin(private val proxy: VisionCameraProxy) : FrameProcessorPlugin() {
    private var _resizeBuffer: I420Buffer? = null
    private var _destinationArray: SharedArray? = null
    companion object {
        private const val TAG = "ResizePlugin"
    }

    private fun wrapArrayInPlane(array: SharedArray, rowStride: Int): Plane {
        return object: Plane {
            override val buffer: ByteBuffer
                get() = array.byteBuffer
            override val rowStride: Int
                get() = rowStride
        }
    }

    private fun getCachedResizeBuffer(width: Int, height: Int): I420Buffer {
        if (_resizeBuffer == null || _resizeBuffer!!.width != width || _resizeBuffer!!.height != height) {
            Log.i(TAG, "Allocating _resizeBuffer... (size: ${width}x${height})")
            _resizeBuffer = I420Buffer.allocate(width, height)
        }
        return _resizeBuffer!!
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
        Log.i(TAG, "Frame Format: ${frame.pixelFormat} (${image.format})")
        if (image.format != ImageFormat.YUV_420_888) {
            throw Error("Frame is not in yuv format! Set pixelFormat=\"yuv\" on the <Camera>. (Expected: YUV_420_888, Received: ${image.format})")
        }

        val buffer = image.toI420Buffer()

        val resizeBuffer = getCachedResizeBuffer(targetWidth, targetHeight)

        Log.i(TAG, "Resizing ${frame.width}x${frame.height} Frame to ${targetWidth}x${targetHeight}...")
        buffer.scale(resizeBuffer, FilterMode.BILINEAR)

        val argbSize = targetWidth * targetHeight * targetFormat.bytesPerPixel
        if (_destinationArray == null || _destinationArray!!.byteBuffer.remaining() != argbSize) {
            Log.i(TAG, "Allocating _argbArray... (size: $argbSize)")
            _destinationArray = SharedArray(proxy, argbSize)
        }
        _destinationArray!!.byteBuffer.rewind()

        val plane = wrapArrayInPlane(_destinationArray!!, targetWidth * targetFormat.bytesPerPixel)

        Log.i(TAG, "Converting to $targetFormat...")
        when (targetFormat) {
            RGBFormat.RGB_8 -> {
                val argbBuffer = Rgb24Buffer.wrap(plane, targetWidth, targetHeight)
                resizeBuffer.convertTo(argbBuffer)
            }
            RGBFormat.BGR_8 -> {
                throw Error("bgr-uint8 is not yet implemented!")
            }
            RGBFormat.ARGB_8 -> {
                val argbBuffer = ArgbBuffer.wrap(plane, targetWidth, targetHeight)
                resizeBuffer.convertTo(argbBuffer)
            }
            RGBFormat.RGBA_8 -> {
                val argbBuffer = RgbaBuffer.wrap(plane, targetWidth, targetHeight)
                resizeBuffer.convertTo(argbBuffer)
            }
            RGBFormat.BGRA_8 -> {
                val argbBuffer = BgraBuffer.wrap(plane, targetWidth, targetHeight)
                resizeBuffer.convertTo(argbBuffer)
            }
            RGBFormat.ABGR_8 -> {
                val argbBuffer = AbgrBuffer.wrap(plane, targetWidth, targetHeight)
                resizeBuffer.convertTo(argbBuffer)
            }
        }
        Log.i(TAG, "Resized & Converted!")

        return _destinationArray
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
                    "rgba-uint8" -> RGBA_8
                    "argb-uint8" -> ARGB_8
                    "bgra-uint8" -> BGRA_8
                    "bgr-uint8" -> BGR_8
                    "abgr-uint8" -> ABGR_8
                    else -> throw Error("Invalid PixelFormat! ($string)")
                }
            }
        }
    }
}
