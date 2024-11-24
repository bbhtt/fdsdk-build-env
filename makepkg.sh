#!/bin/sh

top_dir="$(pwd)"

build_pkg() {
    dir="$1"
    if test -f "$dir/PKGBUILD"; then
        cd "$dir" && makepkg -Ccsir --needed --noconfirm
        cd "$top_dir"
    fi
}

for i in $(find . -maxdepth 1 -mindepth 1 -type d ! -path './.git'); do
    build_pkg "$i"
done
