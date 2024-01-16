import { Frame, VisionCameraProxy } from 'react-native-vision-camera';

const plugin = VisionCameraProxy.initFrameProcessorPlugin('resize');

interface Options {
  size: {
    width: number;
    height: number;
  };
  pixelFormat:
    | 'yuv (4:2:0)'
    | 'yuv (4:4:4)'
    | 'yuv (4:2:2)'
    | 'rgb'
    | 'bgr'
    | 'bgra'
    | 'argb';
}

/**
 * Resizes the given Frame to the target width/height, as well as crop the Frame or convert it's pixelformat
 * @param frame
 */
export function resize(frame: Frame, options: Options): ArrayBuffer {
  'worklet';
  if (plugin == null)
    throw new Error(
      'Cannot find vision-camera-resize-plugin! Did you install the native dependency properly?'
    );

  // @ts-expect-error
  return plugin.call(frame, options);
}
