# bad-assembler

Simple video viewer for x86 real mode that works without an OS.

## How to build

Prerequisites: `ffmpeg`, `nasm`, `qemu` and python packages `pyav` and `numpy`.

1. Put your video to `assets/` directory.

2. Run the `prepare-video.sh` script to create a binary video file.

   ```bash
   $ ./scripts/prepare-video.sh assets/your-video.mp4 20 # <- 20 is FPS
   ```

3. Change `TIMER_FREQUENCY` option in your `badapple.asm`.

4. Run the `build.sh` script to compile source code (yes, i know about Makefile).

5. Run the `run-qemu.sh` script to run QEMU virtual machine.

Your disk image will be in out/disk.img.

## About badapple.asm parameters

This program THEORETICALLY works with 320x240 video files, so
you can change `DRAW_FUNCTION` to `video_set_pixel` if you want.

Maybe I could add some meta information to binary video to
make this step run automatically, but I'm too lazy. :3

You also need to change `VIDEO_WIDTH` and `VIDEO_HEIGHT` parameters
to your video width and height, but video won't be stretched or
centered.

You may also change `SECTORS_PER_READ` parameter to `72` if your
disk image size is more than 1.44MiB.
