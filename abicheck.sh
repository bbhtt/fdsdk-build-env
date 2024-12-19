#!/bin/sh

set -e

checkcmd() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo "$1 not found"
        exit 1
    fi
}

checkcmd "abidiff"

usage() {
    echo "Usage: $0 --lib LIB_NAME [--old-root OLD_ROOT] [--new-root NEW_ROOT] [-- ABIDIFF_FLAGS]"
    echo
    echo "Options:"
    echo "  --lib LIB_NAME       Specify the library name"
    echo "  --old-root OLD_ROOT  Path to the old root directory (default: old-image)"
    echo "  --new-root NEW_ROOT  Path to the new root directory (default: new-image)"
    echo "  ABIDIFF_FLAGS        Optional additional flags to pass to abidiff (after --)"
    exit 1
}

OLD_ROOT="old-image"
NEW_ROOT="new-image"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --lib)
            LIB_NAME="$2"
            shift 2
            ;;
        --old-root)
            OLD_ROOT="$2"
            shift 2
            ;;
        --new-root)
            NEW_ROOT="$2"
            shift 2
            ;;
        --)
            shift
            ABIDIFF_FLAGS="$@"
            break
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$LIB_NAME" ]; then
    usage
fi

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

HEADERS_DIR1="$OLD_ROOT/usr/include"
HEADERS_DIR2="$NEW_ROOT/usr/include"
DEBUG_INFO_DIR1="$OLD_ROOT/usr/lib/debug"
DEBUG_INFO_DIR2="$NEW_ROOT/usr/lib/debug"
LIB_PATH_COMMON="usr/$LIB_DIR/$LIB_NAME"
LIB_PATH1="$OLD_ROOT/$LIB_PATH_COMMON"
LIB_PATH2="$NEW_ROOT/$LIB_PATH_COMMON"

if [ ! -f "$LIB_PATH1" ]; then
    echo "Unable to find $LIB_PATH1"
    exit 1
fi

if [ ! -f "$LIB_PATH2" ]; then
    echo "Unable to find $LIB_PATH2"
    exit 1
fi

ABIDIFF_CMD="abidiff --headers-dir1 \"$HEADERS_DIR1\" \
    --headers-dir2 \"$HEADERS_DIR2\" \
    --debug-info-dir1 \"$DEBUG_INFO_DIR1\" \
    --debug-info-dir2 \"$DEBUG_INFO_DIR2\" \
    \"$LIB_PATH1\" \"$LIB_PATH2\" \
    --drop-private-types"

if [ -n "$ABIDIFF_FLAGS" ]; then
    eval "$ABIDIFF_CMD $ABIDIFF_FLAGS"
else
    eval "$ABIDIFF_CMD"
fi
