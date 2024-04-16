#!/usr/bin/env python3

import argparse
import glob
import logging
import os

import coloredlogs
import numpy as np
from PIL import Image, ImageDraw, ImageOps

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                                    Arguments
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

arg_parser = argparse.ArgumentParser()

arg_parser.add_argument(
    '-i',
    '--input-directory',
    help='Directory from which to read images',
    type=str,
    required=True,
)
arg_parser.add_argument(
    '-o',
    '--output-directory',
    help='Directory into which to put the output',
    type=str,
    required=True,
)
arg_parser.add_argument(
    '-b',
    '--background',
    help='Background color to use',
    default='white',
    type=str,
)
arg_parser.add_argument(
    '-r',
    '--radius',
    help='Radius to use for rounding corners of the background image',
    type=float,
    default=80,
)
arg_parser.add_argument(
    '-e',
    '--extension',
    help='Image file extension to read',
    type=str,
    default='png',
)

args = arg_parser.parse_args()

ARG_INPUT_DIRECTORY: str = args.input_directory
ARG_OUTPUT_DIRECTORY: str = args.output_directory
ARG_BACKGROUND: str = args.background
ARG_RADIUS: float = args.radius
ARG_EXTENSION: str = args.extension

logger = logging.getLogger()
coloredlogs.install(
    level=os.environ.get('LOGLEVEL', 'INFO').upper(), logger=logger
)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                             Get list of all images
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

input_images = [
    Image.open(im)
    for im in glob.glob(f'{ARG_INPUT_DIRECTORY}/*{ARG_EXTENSION}')
]

if len(input_images) == 0:
    logger.error(
        f'No images found with extension "{args.extension}" in directory {args.input_directory}'
    )
    exit(1)
else:
    logger.debug(f'Found images: {[ im.filename for im in input_images ]}')
    logger.info(f'Opened {len(input_images)} {ARG_EXTENSION} images')

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                            Find largest bounding box
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

logger.info('Extracting largest bounding box of staff systems ...')


def get_bounding_box(
    image: Image.Image,
) -> dict[str, tuple[int, ...]]:
    """Get bounding box of staff system contained in the image

    Assumes that only a single staff system is present.

    Returns two tuples:
        - The two points describing the bounding box in the image (x1,x2,y1,y2)
        - The bounding box size (x,y)
    """
    x1, y1, x2, y2 = -1, -1, -1, -1
    pixels = np.array(image, dtype=np.uint8)
    for x in range(image.size[0]):
        first = pixels[0, x]
        if not np.all(pixels[1:, x] == first):
            x1 = x
            break
    for x in reversed(range(image.size[0])):
        first = pixels[0, x]
        if not np.all(pixels[1:, x] == first):
            x2 = x
            break
    for y in range(image.size[1]):
        first = pixels[y, 0]
        if not np.all(pixels[y, 1:] == first):
            y1 = y
            break
    for y in reversed(range(image.size[1])):
        first = pixels[y, 0]
        if not np.all(pixels[y, 1:] == first):
            y2 = y
            break
    w, h = x2 - x1, y2 - y1
    return {'bb_points': (x1, y1, x2, y2), 'bbox': (w, h)}


largest_width: int = 0
largest_height: int = 0
input_image_boxes = {im.filename: get_bounding_box(im) for im in input_images}
for box in input_image_boxes.values():
    w, h = box['bbox']
    if w > largest_width:
        largest_width = w
    if h > largest_height:
        largest_height = h
bbox = (largest_width, largest_height)
logger.debug(f'Largest bounding box: {bbox}')

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                             Create background image
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

logger.info('Creating background image ...')

background_image = Image.new('RGBA', bbox)
background_draw = ImageDraw.Draw(background_image)
background_draw.rounded_rectangle(
    (0, 0, bbox[0], bbox[1]), ARG_RADIUS, ARG_BACKGROUND
)
logger.debug('Created background image')

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                             Make images transparent
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

logger.info('Centering and making images transparent ...')

output_images = []
for im in input_images:
    mask = ImageOps.invert(im.convert('L'))
    im.putalpha(mask)
    im_bbox = input_image_boxes[im.filename]['bbox']
    points = input_image_boxes[im.filename]['bb_points']
    cropped = im.crop(points)
    centered = Image.new('RGBA', bbox)
    centered.filename = im.filename
    centered.paste(
        cropped,
        (
            int((bbox[0] / 2) - (im_bbox[0] / 2)),
            int((bbox[1] / 2) - (im_bbox[1] / 2)),
        ),
    )
    output_images.append(centered)

logger.debug('Made all images transprent')

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                                   Save images
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

background_outfile = f'{ARG_OUTPUT_DIRECTORY}/background.png'
background_image.save(background_outfile)
logger.info(f'Writing file: {background_outfile}')

for im in output_images:
    name = os.path.basename(im.filename)
    outfile = f'{ARG_OUTPUT_DIRECTORY}/{name}'
    im.save(outfile)
    logger.info(f'Writing file: {outfile}')
