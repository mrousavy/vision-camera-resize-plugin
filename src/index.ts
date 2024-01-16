import { Frame, VisionCameraProxy } from 'react-native-vision-camera';

const resizePlugin = VisionCameraProxy.initFrameProcessorPlugin('resize');

interface Options {
  size: {
    width: number;
    height: number;
  };
  pixelFormat:
    | 'rgb (8-bit)'
    | 'rgba (8-bit)'
    | 'argb (8-bit)'
    | 'bgra (8-bit)'
    | 'bgr (8-bit)'
    | 'abgr (8-bit)';
}

/**
 * Resizes the given Frame to the target width/height and
 * convert it to the given pixel format.
 */
export function resize(frame: Frame, options: Options): ArrayBuffer {
  'worklet';
  if (resizePlugin == null)
    throw new Error(
      'Cannot find vision-camera-resize-plugin! Did you install the native dependency properly?'
    );

  // @ts-expect-error
  return resizePlugin.call(frame, options);
}
