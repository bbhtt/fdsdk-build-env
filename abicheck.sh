#!/bin/sh

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 LIB_NAME"
    exit 1
fi

LIB_NAME="$1"
ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        LIB_DIR="lib/x86_64-linux-gnu"
        ;;
    aarch64)
        LIB_DIR="lib/aarch64-linux-gnu"
        ;;
    i386)
        LIB_DIR="lib/i386-linux-gnu"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

HEADERS_DIR1="old-image/usr/include"
HEADERS_DIR2="new-image/usr/include"
DEBUG_INFO_DIR1="old-image/usr/lib/debug"
DEBUG_INFO_DIR2="new-image/usr/lib/debug"
LIB_PATH_COMMON="usr/$LIB_DIR/$LIB_NAME"
LIB_PATH1="old-image/$LIB_PATH_COMMON"
LIB_PATH2="new-image/$LIB_PATH_COMMON"

if [ ! -f "$LIB_PATH1" ] || [ ! -f "$LIB_PATH2" ]; then
    echo "Unable to find $LIB_PATH_COMMON"
    exit 1
fi

abidiff --headers-dir1 "$HEADERS_DIR1" \
        --headers-dir2 "$HEADERS_DIR2" \
        --debug-info-dir1 "$DEBUG_INFO_DIR1" \
        --debug-info-dir2 "$DEBUG_INFO_DIR2" \
        "$LIB_PATH1" "$LIB_PATH2" \
        --drop-private-types

