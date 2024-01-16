import { Frame, VisionCameraProxy } from 'react-native-vision-camera';

const resizePlugin = VisionCameraProxy.initFrameProcessorPlugin('resize');
const convertPlugin = VisionCameraProxy.initFrameProcessorPlugin('convert');

interface ResizeOptions {
  width: number;
  height: number;
}

/**
 * Resizes the given Frame to the target width/height.
 */
export function resize(frame: Frame, options: ResizeOptions): ArrayBuffer {
  'worklet';
  if (resizePlugin == null)
    throw new Error(
      'Cannot find vision-camera-resize-plugin! Did you install the native dependency properly?'
    );

  // @ts-expect-error
  return resizePlugin.call(frame, options);
}

interface ConvertOptions {
  pixelFormat:
    | 'rgb (8-bit)'
    | 'rgba (8-bit)'
    | 'argb (8-bit)'
    | 'bgra (8-bit)'
    | 'bgr (8-bit)'
    | 'abgr (8-bit)';
}

/**
 * Converts the given Frame to the target pixel-format and pixel-layout.
 */
export function convert(frame: Frame, options: ConvertOptions): ArrayBuffer {
  'worklet';
  if (convertPlugin == null)
    throw new Error(
      'Cannot find vision-camera-resize-plugin! Did you install the native dependency properly?'
    );

  // @ts-expect-error
  return convertPlugin.call(frame, options);
}
