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

    const result = plugin.resize(frame, {
      size: {
        width: 100,
        height: 100,
      },
      pixelFormat: 'rgb-uint8',
    });
    const array = new Uint8Array(result);

    const end = performance.now();

    console.log(
      `Resized ${frame.width}x${frame.height} into 100x100 frame (${
        array.length
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
