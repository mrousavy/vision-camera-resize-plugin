# vision-camera-resize-plugin

A [VisionCamera](https://github.com/mrousavy/react-native-vision-camera) Frame Processor Plugin for fast and efficient Frame resizing, cropping and pixel-format conversion using GPU-acceleration and CPU-vector based operations.

## Installation

1. Install react-native-vision-camera and make sure Frame Processors are enabled.
2. Install vision-camera-resize-plugin:
    ```sh
    yarn add vision-camera-resize-plugin
    cd ios && pod install
    ```

## Usage

```tsx
import { resize } from 'vision-camera-resize-plugin';

function App() {
  const frameProcessor = useFrameProcessor((frame) => {
    'worklet'

    const resized = resize(frame, {
      size: {
        width: 100,
        height: 100
      },
      pixelFormat: 'rgb (8-bit)'
    })
    const array = new Uint8Array(resized)
  }, [])

  return <Camera frameProcessor={frameProcessor} {...props} />
}
```

## Pixel Formats

The resize plugin operates in RGB colorspace, and all values are in `uint8`.

<table>
<tr>
<th>Name</th>
<th><code>0</code></th>
<th><code>1</code></th>
<th><code>2</code></th>
<th><code>3</code></th>
</tr>

<tr>
<td><code>rgb (8-bit)</code></td>
<td>R</td>
<td>G</td>
<td>B</td>
<td>R</td>
</tr>

<tr>
<td><code>rgba (8-bit)</code></td>
<td>R</td>
<td>G</td>
<td>B</td>
<td>A</td>
</tr>

<tr>
<td><code>argb (8-bit)</code></td>
<td>A</td>
<td>R</td>
<td>G</td>
<td>B</td>
</tr>

<tr>
<td><code>bgra (8-bit)</code></td>
<td>B</td>
<td>G</td>
<td>R</td>
<td>A</td>
</tr>

<tr>
<td><code>bgr (8-bit)</code></td>
<td>B</td>
<td>G</td>
<td>R</td>
<td>B</td>
</tr>

<tr>
<td><code>abgr (8-bit)</code></td>
<td>A</td>
<td>B</td>
<td>G</td>
<td>R</td>
</tr>

</table>

## react-native-fast-tflite

The vision-camera-resize-plugin can be used together with [react-native-fast-tflite](https://github.com/mrousavy/react-native-fast-tflite) to prepare the input tensor data.

For example, to use the [efficientdet](https://www.kaggle.com/models/tensorflow/efficientdet/frameworks/tfLite) TFLite model to detect objects inside a Frame, simply add the model to your app's bundle, set up VisionCamera and react-native-fast-tflite, and resize your Frames accordingly.

From the model's description on the website, we understand that the model expects 320 x 320 x 3 buffers as input, where the format is uint8 rgb.

```ts
const objectDetection = useTensorflowModel(require('assets/efficientdet.tflite'))
const model = objectDetection.state === "loaded" ? objectDetection.model : undefined

const frameProcessor = useFrameProcessor((frame) => {
  'worklet'

  const data = resize(frame, {
    size: {
      width: 320,
      height: 320,
    },
    pixelFormat: 'rgb (8-bit)'
  })
  const output = model.runSync([data])

  const numDetections = output[0]
  console.log(`Detected ${numDetections} objects!`)
}, [model])
```

## Benchmarks

I benchmarked vision-camera-resize-plugin on an iPhone 15 Pro, using the following code:

```tsx
const start = performance.now()
const result = resize(frame, {
  size: {
    width: 100,
    height: 100,
  },
  pixelFormat: 'rgb (8-bit)',
})
const end = performance.now();

const diff = (end - start).toFixed(2)
console.log(`Resize and conversion took ${diff}ms!`)
```

And when running on 1080x1920 yuv Frames, I got the following results:

```
 LOG  Resize and conversion took 6.48ms
 LOG  Resize and conversion took 6.06ms
 LOG  Resize and conversion took 5.89ms
 LOG  Resize and conversion took 5.97ms
 LOG  Resize and conversion took 6.98ms
```

This means the Frame Processor can run at up to ~160 FPS.

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
