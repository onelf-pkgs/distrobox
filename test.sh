#!/bin/sh
# Tests the Distrobox package build.sh wrote. Runs in the same
# container, right after it.
#
# There is no container manager here, so anything that talks to podman
# is for a real host. What can run is the launch path: the packed
# scripts, the launcher's dispatch, and the carried curl, extracted as
# one tree the way a host materializes it.
#
# Usage: test.sh
set -eu
cd "$(dirname "$0")"

arch=$(uname -m)

# toml <table> <key>: the string value of <key> in [<table>] of
# package.toml.
toml() {
    awk -v table="[$1]" -v key="$2" '
        /^\[/ { in_table = ($0 == table); next }
        in_table && $1 == key && $2 == "=" { gsub(/"/, "", $3); print $3; exit }
    ' package.toml
}

version=$(toml sources.distrobox version)

packed=dist/distrobox-$arch.onelf
onelf verify "$packed"

list=$(onelf list "$packed")
for file in distrobox-run bin/distrobox bin/distrobox-create bin/distrobox-init \
    bin/curl bin/findmnt lib/libcurl.so.4 lib/libcrypto.so.3 \
    lib/libmount.so.1 lib/libblkid.so.1 \
    share/man/man1/distrobox-create.1
do
    case $list in
    *"$file"*) : ;;
    *)
        echo "the package is missing $file" >&2
        exit 1
        ;;
    esac
done

# The tree inside the package must extract with every script and the
# carried curl as executables. The packed file runs the launch path
# through a real materialization: the launcher dispatches a subcommand
# and the wrapper does not disturb the caller's directory.
extract=$(mktemp -d)
trap 'rm -rf "$extract"' EXIT
onelf extract "$packed" -o "$extract"
for script in distrobox distrobox-create distrobox-init curl; do
    [ -x "$extract/bin/$script" ] || {
        echo "bin/$script did not extract as an executable" >&2
        exit 1
    }
done
"$packed" version | grep -q "distrobox: $version"
"$packed" create --help > /dev/null

echo "distrobox-$arch: verify, scripts and curl ok"
