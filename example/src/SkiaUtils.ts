import {
	AlphaType,
	ColorType,
	type SkData,
	Skia,
	type SkImage,
} from "@shopify/react-native-skia";
import type { Options } from "vision-camera-resize-plugin";

type PixelFormat = Options<"uint8">["pixelFormat"];

let lastWarn: PixelFormat | undefined;
lastWarn = undefined;
function warnNotSupported(pixelFormat: PixelFormat) {
	if (lastWarn !== pixelFormat) {
		console.log(
			`Pixel Format '${pixelFormat}' is not natively supported by Skia! ` +
				`Displaying a fall-back format that might use wrong colors instead...`,
		);
		lastWarn = pixelFormat;
	}
}

function getSkiaTypeForPixelFormat(pixelFormat: PixelFormat): ColorType {
	switch (pixelFormat) {
		case "abgr":
		case "argb":
			warnNotSupported(pixelFormat);
			return ColorType.RGBA_8888;
		case "bgr":
			warnNotSupported(pixelFormat);
			return ColorType.RGB_888x;
		case "rgb":
			return ColorType.RGB_888x;
		case "rgba":
			return ColorType.RGBA_8888;
		case "bgra":
			return ColorType.BGRA_8888;
	}
}
function getComponentsPerPixel(pixelFormat: PixelFormat): number {
	switch (pixelFormat) {
		case "abgr":
		case "rgba":
		case "bgra":
		case "argb":
			return 4;
		case "rgb":
		case "bgr":
			return 3;
	}
}

export function createSkiaImageFromData(
	data: SkData,
	width: number,
	height: number,
	pixelFormat: PixelFormat,
): SkImage | null {
	const componentsPerPixel = getComponentsPerPixel(pixelFormat);

	const image = Skia.Image.MakeImage(
		{
			width: width,
			height: height,
			alphaType: AlphaType.Opaque,
			colorType: getSkiaTypeForPixelFormat(pixelFormat),
		},
		data,
		width * componentsPerPixel,
	);
	// console.info(image, componentsPerPixel);
	return image;
}
