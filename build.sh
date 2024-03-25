#!/usr/bin/env bash

if [ ! -e "out/video/video-disk.img" ]
then
    echo "Run the prepare-video.sh script first!"
    exit 1
fi

mkdir -p out/nasm
nasm -f bin -o out/nasm/badapple.bin src/badapple.asm

cp "out/video/video-disk.img" "out/disk.img"
dd if=out/nasm/badapple.bin of=out/disk.img conv=notrunc
