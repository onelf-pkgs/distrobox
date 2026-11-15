#!/bin/sh
# Builds Distrobox for this machine's architecture into dist/:
#
#   distrobox-<arch>.onelf
#
# Distrobox is upstream's POSIX shell scripts, used as they publish;
# there is nothing to compile. The tree carries the scripts, their man
# pages, and two host binaries, the tools outside POSIX and coreutils
# the scripts call: curl for the `create --compatibility` table, and
# findmnt for create's podman-with-runc shared-mount check, which it
# calls once per top-level directory without any guard. The container
# manager comes from the host PATH, where the podman package installs
# itself; crun is checked only on podman-with-runc setups and stays the
# host's business.
#
# Bundling and packing go through the checked-in recipe: `onelf
# build` bundles the library closures and packs in one pass, and
# strip = true keeps the copied libraries lean.
#
# Usage: build.sh
#
# Runs as root in a Void Linux (glibc) container with this directory as
# the working directory and onelf on PATH.
set -eu
cd "$(dirname "$0")"

arch=$(uname -m)
case $arch in
x86_64 | aarch64) ;;
*)
    echo "unsupported architecture: $arch" >&2
    exit 1
    ;;
esac

# toml <table> <key>: the string value of <key> in [<table>] of
# package.toml.
toml() {
    awk -v table="[$1]" -v key="$2" '
        /^\[/ { in_table = ($0 == table); next }
        in_table && $1 == key && $2 == "=" { gsub(/"/, "", $3); print $3; exit }
    ' package.toml
}

version=$(toml sources.distrobox version)
release=$(sed -n 's/^release = //p' package.toml)

# The runtime installs only a strictly newer revision, so a client is
# never rolled back. Upstream versions have four numeric parts, and
# the release rides behind them as the fifth: 1.8.2.5 release 1 is
# 10080020051. awk reads zero-padded parts, such as the 05 of
# 1.1.05, as decimal.
revision=$(echo "$version.$release" | awk -F. '
    NF != 5 { exit 1 }
    { for (i = 2; i <= 4; i++) if ($i >= 10000) exit 1 }
    { printf "%.0f", $1 * 1e10 + $2 * 1e7 + $3 * 1e4 + $4 * 1e1 + $5 }
') || {
    echo "version $version release $release does not fit an update revision" >&2
    exit 1
}

xbps-install -Syu xbps > /dev/null
xbps-install -Syu > /dev/null
xbps-install -y curl bsdtar patchelf util-linux > /dev/null

work=$PWD/build/work
file=build/src/distrobox-$version.tar.gz
if [ ! -f "$file" ]; then
    mkdir -p build/src
    url=$(toml sources.distrobox url | sed "s/{version}/$version/")
    curl -fL --retry 3 -o "$file.part" "$url"
    mv "$file.part" "$file"
fi
echo "$(toml sources.distrobox sha256)  $file" | sha256sum -c - > /dev/null

rm -rf "$work"
mkdir -p "$work"
bsdtar -xzf "$file" -C "$work"
src=$work/distrobox-$version

tree=$work/distrobox
mkdir -p "$tree/bin" "$tree/share/man/man1"
for script in "$src"/distrobox "$src"/distrobox-*; do
    case ${script##*/} in
    distrobox-*) cp "$script" "$tree/bin/" ;;
    esac
done
cp "$src/distrobox" "$tree/bin/distrobox"
cp "$src"/man/man1/*.1 "$tree/share/man/man1/"
cp -p /usr/bin/curl "$tree/bin/curl"
cp -p /usr/bin/findmnt "$tree/bin/findmnt"
cp distrobox-run "$tree/distrobox-run"
chmod 755 "$tree/distrobox-run"
cd "$OLDPWD"

for needed in \
    "$tree/bin/distrobox" \
    "$tree/bin/distrobox-create" \
    "$tree/bin/distrobox-enter" \
    "$tree/bin/distrobox-init" \
    "$tree/bin/curl" \
    "$tree/bin/findmnt" \
    "$tree/distrobox-run"
do
    [ -e "$needed" ] || {
        echo "the tree is missing $needed" >&2
        exit 1
    }
done

if [ -f update.pub ]; then
    trust="key = \"$PWD/update.pub\""
else
    trust="unsigned = true"
fi

mkdir -p dist
export DISTROBOX_VERSION=$version
cp onelf.toml "$tree/onelf.toml"
cat >> "$tree/onelf.toml" <<EOF

[update]
url = "https://github.com/onelf-pkgs/distrobox/releases/latest/download/distrobox-$arch.onelf"
revision = $revision
$trust
EOF

onelf build "$tree" -o "dist/distrobox-$arch.onelf"

ls -l dist
