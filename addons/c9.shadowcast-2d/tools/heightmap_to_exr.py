from PIL import Image

import OpenEXR
import Imath
import cv2 as cv

from argparse import ArgumentParser
from pathlib import Path
from enum import Enum
import numpy as np


class OutputType(Enum):
    RGBA = 1 # 8 bit RGBA integer representing a 16 bit heightmap + alpha
    EXR  = 2 # 32 bit RGBA float

class HeightFormat(Enum):
    FOREGROUND = 1
    BACKGROUND = 2

# supported_formats = [


def get_args():
    parser = ArgumentParser(description="Generate a heightmap from a grayscale image.")

    parser.add_argument("--infile",
            type=Path,
            help="Path to the input image, either greyscale or RGBA.",
            required=True)

    parser.add_argument("--outdir", type=Path,
            help="Directory to save the output files. Default is the current directory.",
            default=Path.cwd())

    parser.add_argument("--srgb",
            action="store_true",
            help="Convert the image from sRGB before processing.")

    parser.add_argument("--scale",
            type=float,
            default=1.0,
            help="Scale factor for the heightmap. Height values are multiplied "
                 "by this value in the output image. Default is 1.0.")

    parser.add_argument("--floor",
            type=float,
            default=0.0,
            help="Floor value for the heightmap. Default is 0.0.")

    parser.add_argument("--normals", action="store_true",
            help="Generate a normal map from the heightmap.")

    parser.add_argument("--normal-sobel-ksize",
            type=int,
            default=3,
            choices=[-1, 3, 5, 7, 9],
            metavar="N",
            help="Sobel kernel size for normal map generation. Default is 3.")

    parser.add_argument("--normal-full-z-range",
            action="store_true",
            help="Generate normal map with full Z range ([-1, 1] instead of [0, 1]).")

    parser.add_argument("--normal-use-scharr",
            action="store_true",
            help="Use Scharr filter instead of Sobel for normal map generation.")

    args = parser.parse_args()
    return args



def get_rgba_greyscale(im, srgb:bool=False):
    np_r = np.array(im).astype(np.float32) / 255.0
    if srgb:
        np_r = np.pow(np_r, 2.2)
    np_g = np.zeros((im.size[1], im.size[0]), dtype=np.float32)
    np_b = np.zeros((im.size[1], im.size[0]), dtype=np.float32)
    np_a = np.ones((im.size[1], im.size[0]), dtype=np.float32)

    return (np_r, np_g, np_b, np_a)


def get_rgba_colour(im, srgb:bool=False):
    r, g, b, a = im.split()
    max_r = max(np.array(r).max(), 0.0)
    max_g = max(np.array(g).max(), 0.0)
    max_b = max(np.array(b).max(), 0.0)
    max_a = max(np.array(a).max(), 0.0)

    print(f"Max values: R={max_r}, G={max_g}, B={max_b}, A={max_a}")

    np_r = np.array(r).astype(np.float32) / 255.0
    np_g = np.array(g).astype(np.float32) / 255.0
    np_b = np.array(b).astype(np.float32) / 255.0
    np_a = np.array(a).astype(np.float32) / 255.0

    max_np_r = max(np.array(np_r).max(), 0.0)
    max_np_g = max(np.array(np_g).max(), 0.0)
    max_np_b = max(np.array(np_b).max(), 0.0)
    max_np_a = max(np.array(np_a).max(), 0.0)

    print(f"Max values before conversion: R={max_np_r}, G={max_np_g}, B={max_np_b}, A={max_np_a}")

    if srgb:
        np_r = np.pow(np_r, 2.2)
        np_g = np.pow(np_g, 2.2)
        np_b = np.pow(np_b, 2.2)
        np_a = np.pow(np_a, 2.2)

        max_np_r = max(np.array(np_r).max(), 0.0)
        max_np_g = max(np.array(np_g).max(), 0.0)
        max_np_b = max(np.array(np_b).max(), 0.0)
        max_np_a = max(np.array(np_a).max(), 0.0)
        print(f"Max values after sRGB conversion: R={max_np_r}, G={max_np_g}, B={max_np_b}, A={max_np_a}")
    return (np_r, np_g, np_b, np_a)



def get_rgba(im, srgb:bool=False):
    ''' Get Height, Alpha, Zero
        Get the height, alpha, and zero channels from the image.
        * The height is a float32 array representing the heightmap.
        * The alpha is a float32 array representing the alpha channel.
        * The zero is a float32 array of zeros with the same shape as the heightmap.
    '''
    if im.mode == "L":
        return get_rgba_greyscale(im, srgb)
    elif im.mode == "RGBA":
        return get_rgba_colour(im, srgb)
    else:
        raise ValueError(f"Unsupported image mode: {im.mode}")



def generate_normal_map(heights, range_, ksize=5, scharr=False, full_z_range: bool=False):
    # Not why we have to do this, but it appears that the filter has some
    # some gain (which is not unsurprising for convolution filters), which means
    # that normalmap values are not consistent across different kernel sizes.
    # Since the kernel values are not easily available from OpenCV, the gain
    # factor was calculated by fitting the output of the filter to a constant
    # value for different kernel sizes.
    gain = 512.0 * 0.25**ksize
    if ksize == -1:
        gain = 1.0

    gX = cv.Sobel(src=heights, ddepth=cv.CV_32F, dx=1, dy=0, ksize=ksize) * 0.5
    gY = cv.Sobel(src=heights, ddepth=cv.CV_32F, dx=0, dy=1, ksize=ksize) * 0.5

    gX = gX * gain
    gY = gY * gain


    output = np.dstack((-gX,  gY, np.ones_like(gX)))

    output = output / np.linalg.norm(output, axis=2, keepdims=True)
    output = (output * 0.5 + 0.5)

    if full_z_range:
        output[:, :, 2] = (output[:, :, 2] - 0.5) * 2.0


    output = output * 255.0
    output = output.astype(np.uint8)

    return output





if __name__ == '__main__':
    args = get_args()

    im = Image.open(args.infile)

    print(args.infile, im.format, f"{im.size} {im.mode}")

    if not args.outdir.exists():
        print(f"Creating output directory: {args.outdir}")
        args.outdir.mkdir(parents=True, exist_ok=True)

    r, g, b, a = get_rgba(im, args.srgb)
    # print(r.shape, g.shape, b.shape, a.shape)

    r = args.floor + r * args.scale
    g = args.floor + g * args.scale
    g = args.floor + g * args.scale
    a = args.floor + a * args.scale

    heightmap_file = args.outdir / (args.infile.stem + ".heightmap.exr")

    print(f'Generating {heightmap_file}')
    pixel_type = Imath.PixelType(Imath.PixelType.FLOAT)
    channels = {
        'R': Imath.Channel(pixel_type),
        'G': Imath.Channel(pixel_type),
        'B': Imath.Channel(pixel_type),
        'A': Imath.Channel(pixel_type),
    }
    header  = OpenEXR.Header(im.size[1], im.size[0])
    header['channels'] = channels

    outfile = OpenEXR.OutputFile(str(heightmap_file), header)
    outfile.writePixels({
        'R': r.tobytes(),
        'G': g.tobytes(),
        'B': b.tobytes(),
        'A': a.tobytes(),
    })
    outfile.close()


    if args.normals:
        normals_file = args.outdir / (args.infile.stem + ".normalmap.png")
        print(f'Generating {normals_file}')
        normalmap = generate_normal_map(r, 255.0,
                    ksize=args.normal_sobel_ksize,
                    full_z_range=args.normal_full_z_range,
                    scharr=args.normal_use_scharr)
        normalmap_file = Image.fromarray(normalmap, mode='RGB')
        normalmap_file.save(normals_file, format="PNG")




