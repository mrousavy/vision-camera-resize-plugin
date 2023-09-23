import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'vision-camera-resize-plugin' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

// @ts-expect-error
const isTurboModuleEnabled = global.__turboModuleProxy != null;

const VisionCameraResizePluginModule = isTurboModuleEnabled
  ? require('./NativeVisionCameraResizePlugin').default
  : NativeModules.VisionCameraResizePlugin;

const VisionCameraResizePlugin = VisionCameraResizePluginModule
  ? VisionCameraResizePluginModule
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export function multiply(a: number, b: number): Promise<number> {
  return VisionCameraResizePlugin.multiply(a, b);
}
