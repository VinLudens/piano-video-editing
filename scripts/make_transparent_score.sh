#!/bin/bash

SRC="$1"         # Folder to read images from
DEST="$2"        # Folder to write images to
ROUND="${3:-80}" # Amount of rounding for the background image

magick_transform() {
    FNAME="$1"
    OUTNAME="$DEST/$(basename "$FNAME")"
    BGOUTNAME="$DEST/bg_$(basename "$FNAME")"
    GRAY=$(mktemp)
    W="$(identify -format "%w" "$FNAME")"
    H="$(identify -format "%h" "$FNAME")"
    trap "rm -- '$GRAY'" EXIT
    magick "$FNAME" -colorspace LinearGray -negate "$GRAY" &&
        magick "$FNAME" "$GRAY" -alpha off -compose CopyOpacity -composite "$OUTNAME" &&
        magick -size "${W}x${H}" xc:none -fill white -draw "roundrectangle 0,0 ${W},${H} ${ROUND},${ROUND}" "$BGOUTNAME"
    printf '%s -> %s\n' "$FNAME" "$OUTNAME"
}

# for use in 'parallel'
export -f magick_transform
export SRC DEST ROUND

parallel 'magick_transform {}' ::: "$SRC"/*.png
