VIDEO_FILE="$1"
FPS="$2"

mkdir -p out/video
ffmpeg -i "$VIDEO_FILE" -vf "scale=160:100,fps=$FPS" out/video/video.mp4
python scripts/create-video.py out/video/video.mp4 out/video/video.bin

rm -f out/video/video-disk.img

fallocate -l 1440K out/video/video-disk.img
dd if=out/video/video.bin of=out/video/video-disk.img bs=512 seek=1 conv=notrunc

rm -f out/video/video.mp4
rm -f out/video/video.bin

python scripts/calculate-frequency.py "$FPS"
