#!/bin/bash

parser_definition() {
    setup REST help:usage -- "Usage: maketitle ..." ''
    msg -- "Options:"
    param TITLE -t --title -- "Title of the video"
    param COMPOSER -c --composer -- "Name of the composer (i.e. 'by XYZ')"
    param ARTIST -a --artist init:="Piano by VinLudens" -- "Name of the artist (i.e. 'by XYZ')"
    param FPS -f --fps init:=25 -- "Framerate of the title screen"
    disp :usage -h --help
}

eval "$(getoptions parser_definition) exit 1"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                                    Inputs
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

TITLE="${TITLE:-MUSIC TITLE}"
COMPOSER="${COMPOSER:-by COMPOSER}"
ARTIST="${ARTIST:-Piano by VinLudens}"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                                   Settings
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# list fonts with
#   identify -list font
FONTR="C059-Roman"
FONTI="C059-Italic"

IMAGE_SIZE="1920x1080"

TITLE_SIZE=93
COMPOSER_SIZE=53
ARTIST_SIZE=53

TITLE_OUT="title.png"
COMPOSER_OUT="composer.png"
ARTIST_OUT="artist.png"

SEQ_DIR="intro"
FPS=${FPS:-25}

THUMBNAIL_DIR="../thumbnail"
THUMBNAIL_SIZE=140
TITLE_THUMBNAIL="$THUMBNAIL_DIR/$TITLE_OUT"
TITLE_THUMBNAIL_INVERTED="$THUMBNAIL_DIR/${TITLE_OUT%%.*}-inverted.png"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                                Generate images
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

magick -verbose -size "$IMAGE_SIZE" \
    xc:transparent \
    -font "$FONTR" -pointsize "$TITLE_SIZE" \
    -gravity center \
    -draw "text 0,0 '$TITLE'" \
    "$TITLE_OUT"

magick -verbose -size "$IMAGE_SIZE" \
    xc:transparent \
    -font "$FONTI" -pointsize "$COMPOSER_SIZE" \
    -gravity center \
    -draw "text 0,113 '$COMPOSER'" \
    "$COMPOSER_OUT"

magick -verbose -size "$IMAGE_SIZE" \
    xc:transparent \
    -font "$FONTI" -pointsize "$ARTIST_SIZE" \
    -gravity center \
    -draw "text 0,246 '$ARTIST'" \
    "$ARTIST_OUT"

# Make thumbnail title template -------------------------------------------------
if [ -d "$THUMBNAIL_DIR" ]; then
    magick -verbose -size "$IMAGE_SIZE" \
        xc:transparent \
        -font "$FONTR" -pointsize "$THUMBNAIL_SIZE" \
        -gravity center \
        -draw "text 0,0 '$TITLE'" \
        "$TITLE_THUMBNAIL"
    magick -verbose "$TITLE_THUMBNAIL" -channel RGB -negate "$TITLE_THUMBNAIL_INVERTED"
fi

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                       Generate animated image sequence
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# https://stackoverflow.com/questions/61076951/ffmpeg-join-crossfade-5-input-files-videoaudio-into-one-output-file

mkdir -pv "$SEQ_DIR" || rm "$SEQ_DIR/*"

ffmpeg \
    -f lavfi -i color=c=white:s="$IMAGE_SIZE" \
    -loop 1 -i "$TITLE_OUT" \
    -loop 1 -i "$COMPOSER_OUT" \
    -loop 1 -i "$ARTIST_OUT" \
    -filter_complex "
        [0]format=yuva420p,
            fade=out:st=5:d=1:alpha=1,
            setpts=PTS-STARTPTS[v0];
        [1]format=yuva420p,
            fade=in:st=0:d=0.66:alpha=1,
            fade=out:st=4:d=1:alpha=1,
            setpts=PTS-STARTPTS+(1/TB)[v1];
        [2]format=yuva420p,
            fade=in:st=0:d=0.66:alpha=1,
            fade=out:st=3:d=1:alpha=1,
            setpts=PTS-STARTPTS+(2/TB)[v2];
        [3]format=yuva420p,
            fade=in:st=0:d=0.66:alpha=1,
            fade=out:st=2:d=1:alpha=1,
            setpts=PTS-STARTPTS+(3/TB)[v3];
        [v0][v1]overlay[out];
        [out][v2]overlay[out];
        [out][v3]overlay[out]" \
    -t 6 -r "$FPS" \
    -map [out] "$SEQ_DIR/intro%03d.png"

rm "$TITLE_OUT" "$COMPOSER_OUT" "$ARTIST_OUT"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                        Reduce image sequence file size
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# https://stackoverflow.com/a/27269509

# mogrify -verbose -colorspace Gray -depth 8 -separate -average -quality 00 "$SEQ_DIR"/*.png
echo Optimizing PNG files ...
parallel 'optipng -quiet -strip all {}' ::: "$SEQ_DIR"/*.png

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                          Notify finished processing
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

notify-send "maketitle" "Finished producing title sequence"
