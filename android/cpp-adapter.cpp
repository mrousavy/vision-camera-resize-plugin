#include <jni.h>
#include "vision-camera-resize-plugin.h"

extern "C"
JNIEXPORT jdouble JNICALL
Java_com_visioncameraresizeplugin_VisionCameraResizePluginModule_nativeMultiply(JNIEnv *env, jclass type, jdouble a, jdouble b) {
    return visioncameraresizeplugin::multiply(a, b);
}
