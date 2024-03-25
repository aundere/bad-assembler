#!/usr/bin/env python

# My first (and probably last) python script.

# This script converts a video into
# a bad-assembler-compatible format.

from typing import Generator, Iterable

import numpy as np

import itertools
import argparse
import av
import io
import os

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()

    parser.add_argument("input", type=str)
    parser.add_argument("output", type=str)

    return parser.parse_args()

def group_by(it: Iterable, n: int) -> Generator[[int, any], None, None]:
    """Ugly function that divides a list into groups with max length of n."""
    chunks = itertools.groupby(it)
    group = lambda x, n: [ x[i:i + n] for i in range(0, len(x), n) ]

    for key, chunk in chunks:
        for subchunk in group(list(chunk), n):
            yield (key, len(subchunk))

args = parse_args()

stream = open(args.output, "wb")
container = av.open(args.input)

# I don't know how to change FPS with PyAV. :(

# Vectorized NumPy function.
# Returns 1 if brightness is greater than 127, otherwise returns 0.
convert_colors = np.vectorize(lambda x: int(x) >> 7)

for frame in container.decode(video=0):
    frame_data = frame.to_rgb().to_ndarray()

    # Calculate brightness for all frame pixels.
    frame_data = np.dot(frame_data, [ 0.2126, 0.7152, 0.0722 ])

    # Convert brightness to color code.
    frame_data = convert_colors(frame_data)

    # Divide a matrix into chunks of 127 same elements.
    frame_data = group_by(frame_data.flatten().tolist(), 127)

    # Convert groups into bytes.
    frame_data = [ data[1] ^ (data[0] << 7) for data in frame_data ]

    # Write a bytearray to output file.
    stream.write(bytearray(frame_data))

print("Done.")
