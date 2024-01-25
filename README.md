# vision-camera-resize-plugin

A [VisionCamera](https://github.com/mrousavy/react-native-vision-camera) Frame Processor Plugin for fast and efficient Frame resizing, cropping and pixel-format conversion (YUV -> RGB) using GPU-acceleration, CPU-vector based operations and ARM NEON SIMD acceleration.

## Installation

1. Install react-native-vision-camera (>= 3.8.2) and make sure Frame Processors are enabled.
2. Install vision-camera-resize-plugin:
    ```sh
    yarn add vision-camera-resize-plugin
    cd ios && pod install
    ```

## Usage

Use the `resize` plugin within a Frame Processor:

```tsx
const { resize } = useResizePlugin()

const frameProcessor = useFrameProcessor((frame) => {
  'worklet'

  const resized = resize(frame, {
    size: {
      x: 10,
      y: 10,
      width: 192,
      height: 192
    },
    pixelFormat: 'rgb',
    dataType: 'uint8'
  })

  const firstPixel = {
    r: resized[0],
    g: resized[1],
    b: resized[2]
  }
}, [])
```

Or outside of a function component:

```tsx
const { resize } = createResizePlugin()

const frameProcessor = createFrameProcessor((frame) => {
  'worklet'

  const resized = resize(frame, {
    // ...
  })
  // ...
})
```

## Pixel Formats

The resize plugin operates in RGB colorspace.

<table>
<tr>
<th>Name</th>
<th><code>0</code></th>
<th><code>1</code></th>
<th><code>2</code></th>
<th><code>3</code></th>
</tr>

<tr>
<td><code>rgb</code></td>
<td>R</td>
<td>G</td>
<td>B</td>
<td>R</td>
</tr>

<tr>
<td><code>rgba</code></td>
<td>R</td>
<td>G</td>
<td>B</td>
<td>A</td>
</tr>

<tr>
<td><code>argb</code></td>
<td>A</td>
<td>R</td>
<td>G</td>
<td>B</td>
</tr>

<tr>
<td><code>bgra</code></td>
<td>B</td>
<td>G</td>
<td>R</td>
<td>A</td>
</tr>

<tr>
<td><code>bgr</code></td>
<td>B</td>
<td>G</td>
<td>R</td>
<td>B</td>
</tr>

<tr>
<td><code>abgr</code></td>
<td>A</td>
<td>B</td>
<td>G</td>
<td>R</td>
</tr>

</table>

## Data Types

The resize plugin can either convert to uint8 or float32 values:

<table>
<tr>
<th>Name</th>
<th>JS Type</th>
<th>Value Range</th>
<th>Example size</th>
</tr>

<tr>
<td><code>uint8</code></td>
<td><code>Uint8Array</code></td>
<td>0...255</td>
<td>1920x1080 RGB Frame = ~6.2 MB</td>
</tr>

<tr>
<td><code>float32</code></td>
<td><code>Float32Array</code></td>
<td>0.0...1.0</td>
<td>1920x1080 RGB Frame = ~24.8 MB</td>
</tr>

</table>

### Performance

If possible, use one of these two formats:

- `argb` in `uint8`: Can be converted the fastest, but has an additional unused alpha channel.
- `rgb` in `uint8`: Requires one more conversion step from `argb`, but uses 25% less memory due to the removed alpha channel.

All other formats require additional conversion steps, and `float` models have additional memory overhead (4x as big).

When using TensorFlow Lite, try to convert your model to use `argb-uint8` or `rgb-uint8` as it's input type.

## react-native-fast-tflite

The vision-camera-resize-plugin can be used together with [react-native-fast-tflite](https://github.com/mrousavy/react-native-fast-tflite) to prepare the input tensor data.

For example, to use the [efficientdet](https://www.kaggle.com/models/tensorflow/efficientdet/frameworks/tfLite) TFLite model to detect objects inside a Frame, simply add the model to your app's bundle, set up VisionCamera and react-native-fast-tflite, and resize your Frames accordingly.

From the model's description on the website, we understand that the model expects 320 x 320 x 3 buffers as input, where the format is uint8 rgb.

```ts
const objectDetection = useTensorflowModel(require('assets/efficientdet.tflite'))
const model = objectDetection.state === "loaded" ? objectDetection.model : undefined

const { resize } = useResizePlugin()

const frameProcessor = useFrameProcessor((frame) => {
  'worklet'

  const data = resize(frame, {
    size: {
      // center-crop
      x: (frame.width / 2) - (320 / 2),
      y: (frame.height / 2) - (320 / 2),
      width: 320,
      height: 320,
    },
    pixelFormat: 'rgb',
    dataType: 'uint8'
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
    x: 0,
    y: 0,
    width: 100,
    height: 100,
  },
  pixelFormat: 'rgb',
  dataType: 'uint8'
})
const end = performance.now()

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

## Adopting at scale

<a href="https://github.com/sponsors/mrousavy">
  <img align="right" width="160" alt="This library helped you? Consider sponsoring!" src=".github/funding-octocat.svg">
</a>

This library is provided _as is_, I work on it in my free time.

If you're integrating vision-camera-resize-plugin in a production app, consider [funding this project](https://github.com/sponsors/mrousavy) and <a href="mailto:me@mrousavy.com?subject=Adopting vision-camera-resize-plugin at scale">contact me</a> to receive premium enterprise support, help with issues, prioritize bugfixes, request features, help at integrating vision-camera-resize-plugin and/or VisionCamera Frame Processors, and more.


## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
