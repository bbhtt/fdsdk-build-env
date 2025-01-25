#!/bin/bash

# The Unlicense
#
# This is free and unencumbered software released into the public domain.
# Anyone is free to copy, modify, distribute, and perform the software, as well as
# to sublicense it, all without any conditions whatsoever.
#
# See the full text of the Unlicense at: https://unlicense.org/

set -euo pipefail

top_dir="$(pwd)"

build_pkg() {
    dir="$1"
    base=$(basename "$dir")
    if [[ -f "$dir/PKGBUILD" ]]; then
        echo "===> Building $base <==="
        cd "$dir" && makepkg -Ccsir --needed --noconfirm
        echo "===> Finished building $base <==="
        cd "$top_dir"
    fi
}

mapfile -d '' dirs < <(find . -maxdepth 1 -mindepth 1 -type d ! -name '.*' -print0 | sort -z)

for dir in "${dirs[@]}"; do
    build_pkg "$dir"
done
