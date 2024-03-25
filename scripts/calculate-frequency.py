#!/usr/bin/env python

# This script converts a frequency into
# a PIT reload value.

# See TIMER_FREQUENCY in badapple.asm

import argparse

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()

    parser.add_argument('frequency', type=int)

    return parser.parse_args()

args = parse_args()
pit_frequency = int(0x1234DD / args.frequency)

if pit_frequency > 0xFFFF:
    print(f"Cannot set a {args.frequency} as a frequency. Value is too low.")
    quit(1)

print( "! Put this value into your badapple.asm !")
print(f"  %define TIMER_FREQUENCY     {hex(pit_frequency)}")
