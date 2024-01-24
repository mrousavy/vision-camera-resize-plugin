import * as React from 'react';

import { StyleSheet, View } from 'react-native';
import { useTensorflowModel } from 'react-native-fast-tflite';
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useFrameProcessor,
} from 'react-native-vision-camera';
import { useResizePlugin } from 'vision-camera-resize-plugin';

const BlazeFaceModel = {
  url: 'https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/latest/blaze_face_short_range.tflite',
};

export default function App() {
  const permission = useCameraPermission();
  const device = useCameraDevice('back');

  React.useEffect(() => {
    permission.requestPermission();
  }, [permission]);

  const plugin = useResizePlugin();
  const { model } = useTensorflowModel(
    require('../assets/object-detection.tflite')
  );

  const frameProcessor = useFrameProcessor(
    (frame) => {
      'worklet';
      console.log(frame.toString());

      const start = performance.now();

      const result = plugin.resize(frame, {
        size: {
          width: 300,
          height: 300,
        },
        pixelFormat: 'rgb',
        dataType: 'uint8',
      });

      const end = performance.now();
      console.log(
        `Resized ${frame.width}x${frame.height} into 100x100 frame (${
          result.length
        }) in ${(end - start).toFixed(2)}ms`
      );

      if (model != null) {
        console.log('Running object detection...');
        const results = model.runSync([result]);
        const locations = results[0];
        const classes = results[1];
        const scores = results[2];
        const num_detections = results[3];
        console.log(`Detected ${num_detections} objects!`);
      }
    },
    [model]
  );

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
