import * as React from 'react';

import { StyleSheet, View } from 'react-native';
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useFrameProcessor,
} from 'react-native-vision-camera';
import { useResizePlugin } from 'vision-camera-resize-plugin';

export default function App() {
  const permission = useCameraPermission();
  const device = useCameraDevice('back');

  React.useEffect(() => {
    permission.requestPermission();
  }, [permission]);

  const plugin = useResizePlugin();

  const frameProcessor = useFrameProcessor((frame) => {
    'worklet';
    console.log(frame.toString());

    const start = performance.now();

    const targetWidth = 250;
    const targetHeight = 250;

    const result = plugin.resize(frame, {
      scale: {
        width: targetWidth,
        height: targetHeight,
      },
      pixelFormat: 'rgba',
      dataType: 'uint8',
      rotation: '90deg',
      mirror: true,
    });
    console.log(
      result[Math.round(result.length / 2) + 0],
      result[Math.round(result.length / 2) + 1],
      result[Math.round(result.length / 2) + 2],
      result[Math.round(result.length / 2) + 3],
      '(' + result.length + ')'
    );

    const end = performance.now();

    console.log(
      `Resized ${frame.width}x${frame.height} into 100x100 frame (${
        result.length
      }) in ${(end - start).toFixed(2)}ms`
    );
  }, []);

  return (
    <View style={styles.container}>
      {permission.hasPermission && device != null && (
        <Camera
          device={device}
          style={StyleSheet.absoluteFill}
          isActive={true}
          pixelFormat="yuv"
          frameProcessor={frameProcessor}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
