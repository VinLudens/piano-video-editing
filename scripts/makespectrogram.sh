#!/bin/bash

AUDIO_FILE="$1"
VIDEO_FILE="$2"
SG_FILE="$(basename "${AUDIO_FILE%.*}-spectogram.png")"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                                Get Information
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# https://gist.github.com/nrk/2286511

AUDIO_FFPROBE_JSON="$(mktemp)"
VIDEO_FFPROBE_JSON="$(mktemp)"
ffprobe -i "$AUDIO_FILE" -v quiet -print_format json -show_format > "$AUDIO_FFPROBE_JSON"
ffprobe -i "$VIDEO_FILE" -v quiet -print_format json -show_streams > "$VIDEO_FFPROBE_JSON"
trap "rm '$AUDIO_FFPROBE_JSON' '$VIDEO_FFPROBE_JSON'" EXIT

# Audio ------------------------------------------------------------------------
AUDIO_LENGTH="$(jq -r '.format.duration' "$AUDIO_FFPROBE_JSON")"

# Video ------------------------------------------------------------------------
VIDEO_FPS="$(jq -r '.streams[0].r_frame_rate' "$VIDEO_FFPROBE_JSON" | cut -d'/' -f1)"

# Number of frames for audio ---------------------------------------------------
PIXEL_PER_FRAME=1.1     # put slightly more pixels than frames
AUDIO_FRAMES="$(lua -e "print(math.ceil($AUDIO_LENGTH * $VIDEO_FPS * $PIXEL_PER_FRAME))")"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                           Generate Spectogram Image
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SG_WIDTH=4000
SG_HEIGHT="$AUDIO_FRAMES"

ffmpeg -y -i "$AUDIO_FILE" \
    -lavfi showspectrumpic=s="${SG_WIDTH}x${SG_HEIGHT}":mode=combined:saturation=0:fscale=log:orientation=horizontal:legend=0:win_func=poisson:start=20:stop=4200,vflip \
    "$SG_FILE"
