package com.visioncameraresizeplugin

import com.mrousavy.camera.frameprocessor.Frame
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessor.VisionCameraProxy

class ResizePlugin(private val proxy: VisionCameraProxy) : FrameProcessorPlugin() {
    override fun callback(frame: Frame, params: MutableMap<String, Any>?): Any? {
        TODO("Not yet implemented")
    }
}