import * as React from "react";
import { StyleSheet, View } from "react-native";
import {
	Camera,
	useCameraDevice,
	useCameraPermission,
	useFrameProcessor,
} from "react-native-vision-camera";
import { type Options, useResizePlugin } from "vision-camera-resize-plugin";
import { useSharedValue } from "react-native-reanimated";
import {
	Skia,
	Image,
	type SkData,
	Canvas,
	type SkImage,
} from "@shopify/react-native-skia";
import { useRunOnJS } from "react-native-worklets-core";
import { createSkiaImageFromData } from "./SkiaUtils";

type PixelFormat = Options<"uint8">["pixelFormat"];

const WIDTH = 300;
const HEIGHT = 300;
const TARGET_TYPE = "uint8" as const;
const TARGET_FORMAT: PixelFormat = "rgba";

export default function App() {
	const permission = useCameraPermission();
	const device = useCameraDevice("back");
	const previewImage = useSharedValue<SkImage | null>(null);

	React.useEffect(() => {
		permission.requestPermission();
	}, [permission]);

	const plugin = useResizePlugin();

	const updatePreviewImageFromData = useRunOnJS(
		(data: SkData, pixelFormat: PixelFormat) => {
			// const pixels2 = new Uint8Array(WIDTH * HEIGHT * 4);
			// pixels2.fill(255);
			// // let i = 0;
			// for (let x = 0; x < WIDTH; x++) {
			// 	for (let y = 0; y < HEIGHT; y++) {
			// 		pixels2[(x * HEIGHT + y) * 4] = 0;
			// 	}
			// }

			// console.info("hi");
			// const data2 = Skia.Data.fromBytes(pixels);
			// console.info("hi2");
			// console.info(data);
			const image = createSkiaImageFromData(data, WIDTH, HEIGHT, pixelFormat);
			// console.info(data., image?.encodeToBase64());
			previewImage.value?.dispose();
			previewImage.value = image;
		},
		[],
	);

	const frameProcessor = useFrameProcessor(
		(frame) => {
			"worklet";

			const start = performance.now();

			const result = plugin.resize(frame, {
				// crop: {
				// 	x: -50,
				// 	y: -50,
				// 	width: 100,
				// 	height: 100,
				// },
				crop: {
					x: -100,
					y: -100,
					width: WIDTH,
					height: HEIGHT,
				},
				scale: {
					width: WIDTH,
					height: HEIGHT,
				},
				dataType: TARGET_TYPE,
				pixelFormat: TARGET_FORMAT,
				rotation: "90deg",
				mirror: true,
			});

			// const pixels = new Uint8Array(WIDTH * HEIGHT * 4);
			// pixels.fill(255);
			// // let i = 0;
			// for (let x = 0; x < WIDTH; x++) {
			// 	for (let y = 0; y < HEIGHT; y++) {
			// 		pixels[(x * HEIGHT + y) * 4] = 1;
			// 	}
			// }
			// console.info("build");
			const data = Skia.Data.fromBytes(result);
			// console.info("ok");
			updatePreviewImageFromData(data, TARGET_FORMAT).then(() =>
				data.dispose(),
			);
			// data.dispose();
			const end = performance.now();

			console.log(
				`Resized ${frame.width}x${frame.height} into 100x100 frame (${
					result.length
				}) in ${(end - start).toFixed(2)}ms`,
			);
		},
		[updatePreviewImageFromData],
	);

	return (
		<View style={styles.container}>
			{permission.hasPermission && device != null && (
				<Camera
					device={device}
					enableFpsGraph
					style={StyleSheet.absoluteFill}
					isActive={true}
					pixelFormat="yuv"
					frameProcessor={frameProcessor}
				/>
			)}
			<View
				style={[
					styles.canvasWrapper,
					// { borderWidth: 5, borderColor: "green" }
				]}
			>
				<Canvas style={{ width: WIDTH, height: HEIGHT }}>
					<Image
						image={previewImage}
						x={0}
						y={0}
						width={WIDTH}
						height={HEIGHT}
						fit="cover"
					/>
				</Canvas>
			</View>
		</View>
	);
}

const styles = StyleSheet.create({
	container: {
		flex: 1,
		alignItems: "center",
		justifyContent: "center",
	},
	box: {
		width: 60,
		height: 60,
		marginVertical: 20,
	},
	canvasWrapper: {
		position: "absolute",
		bottom: 80,
		left: 20,
	},
});
