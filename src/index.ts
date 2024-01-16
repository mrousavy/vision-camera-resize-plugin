import { Platform } from 'react-native';
import { Frame, VisionCameraProxy } from 'react-native-vision-camera';

const resizePlugin = VisionCameraProxy.initFrameProcessorPlugin('resize');

if (resizePlugin == null) {
  if (Platform.OS === 'android') {
    throw new Error(
      'vision-camera-resize-plugin does not work on Android yet. Contact me through my agency if you want me to add Android support.'
    );
  } else {
    throw new Error(
      'Cannot find vision-camera-resize-plugin! Did you install the native dependency properly?'
    );
  }
}

interface Options {
  size?: {
    width: number;
    height: number;
  };
  pixelFormat?:
    | 'rgb-888'
    | 'rgba-8888'
    | 'argb-8888'
    | 'bgra-8888'
    | 'bgr-888'
    | 'abgr-8888';
}

/**
 * Resizes the given Frame to the target width/height and
 * convert it to the given pixel format.
 */
export function resize(frame: Frame, options: Options): ArrayBuffer {
  'worklet';

  // @ts-expect-error
  return resizePlugin.call(frame, options);
}
