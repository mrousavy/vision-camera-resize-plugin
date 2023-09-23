package com.visioncameraresizeplugin;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.Promise;

abstract class VisionCameraResizePluginSpec extends ReactContextBaseJavaModule {
  VisionCameraResizePluginSpec(ReactApplicationContext context) {
    super(context);
  }

  public abstract void multiply(double a, double b, Promise promise);
}
