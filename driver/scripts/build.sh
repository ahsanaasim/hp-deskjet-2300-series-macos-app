#!/bin/bash
# ============================================================================
# Reproducible build of the hpcups CUPS filter (HPLIP 3.25.2) for macOS.
#
# Produces bin/hpcups — a universal (arm64 + x86_64) binary that depends only
# on system libraries — and ppd/"HP DeskJet 2300 series hpcups.ppd".
#
# Requirements:
#   - Xcode Command Line Tools (clang)
#   - Homebrew packages: cups, jpeg-turbo  (headers only; the resulting
#     binary links against the SYSTEM libcups/libcupsimage)
#
# Usage:  bash build.sh
#
# CRITICAL: -DAPDK_LITTLE_ENDIAN must be defined. Autotools normally sets it
# via AC_C_BIGENDIAN; without it the driver "builds and runs" but silently
# produces garbage (ErnieFilter emits zeros, RGB channel macros read the
# wrong bytes). See README for the full story.
# ============================================================================
set -euo pipefail

HPLIP_VERSION=3.25.2
HPLIP_URL="https://downloads.sourceforge.net/project/hplip/hplip/${HPLIP_VERSION}/hplip-${HPLIP_VERSION}.tar.gz"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"   # корень репозитория
WORK="$(mktemp -d /tmp/hpcups-build.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

CUPS_PREFIX="$(brew --prefix cups)"
JPEG_PREFIX="$(brew --prefix jpeg-turbo)"
[ -f "$CUPS_PREFIX/include/cups/raster.h" ] || { echo "Install deps: brew install cups jpeg-turbo" >&2; exit 1; }

echo "==> Downloading HPLIP $HPLIP_VERSION..."
curl -sL --fail -o "$WORK/hplip.tar.gz" "$HPLIP_URL"
tar xzf "$WORK/hplip.tar.gz" -C "$WORK"
SRC="$WORK/hplip-$HPLIP_VERSION"
cd "$SRC"

# --- shims for Linux-isms and private libjpeg header --------------------------
mkdir -p shim
printf '#pragma once\n#include <stdlib.h>\n' > shim/malloc.h
# jccolor.c needs the private jpegint.h matching the installed jpeg-turbo
JPEG_VER="$(brew list --versions jpeg-turbo | awk '{print $2}')"
curl -sL --fail -o shim/jpegint.h \
  "https://raw.githubusercontent.com/libjpeg-turbo/libjpeg-turbo/${JPEG_VER}/src/jpegint.h" ||
curl -sL --fail -o shim/jpegint.h \
  "https://raw.githubusercontent.com/libjpeg-turbo/libjpeg-turbo/3.2.0/src/jpegint.h"

# --- source list from Makefile.am --------------------------------------------
sed -n '/^hpcups_SOURCES/,/^hpcups_LDADD/p' Makefile.am | tr ' \t\\' '\n' \
  | grep -E '\.(c|cpp)$' | sort -u > srcs.txt
echo "==> $(wc -l < srcs.txt | tr -d ' ') source files"

CXXFLAGS="-O2 -std=c++11 -w -DAPDK_LITTLE_ENDIAN -DDISABLE_IMAGEPROCESSOR \
  -DVERSION=\"${HPLIP_VERSION}\" -include common/utils.h \
  -I. -Ishim -Iprnt/hpcups -Icommon -Iio/hpmud \
  -I$CUPS_PREFIX/include -I$JPEG_PREFIX/include"
CFLAGS="-O2 -w -DAPDK_LITTLE_ENDIAN -DVERSION=\"${HPLIP_VERSION}\" -DCONFDIR=\"/etc/hp\" \
  -I. -Ishim -Icommon -Iprnt/hpcups -I$JPEG_PREFIX/include"

# x86_64 slice: no Intel libjpeg.a in Homebrew anymore, so stub out libjpeg
# entry points. They are reachable only from the JetReady encoder used by
# certain LaserJets — never by DeskJet/PCL3GUI printers.
cat > shim/jpeg_stubs.c <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
static void die(const char *f){ fprintf(stderr, "hpcups: jpeg stub called: %s\n", f); exit(1); }
void *jpeg_std_error(void *e){ return e; }
void jpeg_CreateCompress(void *c, int v, size_t s){ die("jpeg_CreateCompress"); }
void jpeg_destroy_compress(void *c){ }
void jpeg_set_defaults(void *c){ die("jpeg_set_defaults"); }
void jpeg_set_quality(void *c, int q, int b){ die("jpeg_set_quality"); }
void jpeg_set_colorspace(void *c, int cs){ die("jpeg_set_colorspace"); }
void jpeg_add_quant_table(void *c, int t, const unsigned int *q, int s, int b){ die("jpeg_add_quant_table"); }
void jpeg_suppress_tables(void *c, int s){ die("jpeg_suppress_tables"); }
void jpeg_start_compress(void *c, int w){ die("jpeg_start_compress"); }
unsigned jpeg_write_scanlines(void *c, void *l, unsigned n){ die("jpeg_write_scanlines"); return 0; }
void jpeg_finish_compress(void *c){ die("jpeg_finish_compress"); }
EOF

build_slice() {  # $1 = arch, $2 = objdir, $3 = jpeg link ("static"|"stubs")
    local arch="$1" obj="$2" jpeg="$3"
    mkdir -p "$obj"
    while IFS= read -r f; do
        # unique object names: the case-insensitive APFS would merge
        # Utils.cpp -> Utils.o and utils.c -> utils.o otherwise
        local o="$obj/$(echo "$f" | tr '/.' '__').o"
        case "$f" in
            *.cpp) clang++ -arch "$arch" $CXXFLAGS -c "$f" -o "$o" ;;
            *.c)   clang   -arch "$arch" $CFLAGS   -c "$f" -o "$o" ;;
        esac
    done < srcs.txt
    if [ "$jpeg" = "stubs" ]; then
        clang -arch "$arch" -O2 -w -c shim/jpeg_stubs.c -o "$obj/jpeg_stubs.o"
        clang++ -arch "$arch" -o "$obj/hpcups" "$obj"/*.o -lcups -lcupsimage -lz
    else
        clang++ -arch "$arch" -o "$obj/hpcups" "$obj"/*.o "$JPEG_PREFIX/lib/libjpeg.a" -lcups -lcupsimage -lz
    fi
}

echo "==> Building arm64 slice..."
build_slice arm64 build_arm64 static
echo "==> Building x86_64 slice..."
build_slice x86_64 build_x86_64 stubs

echo "==> Creating universal binary..."
lipo -create build_arm64/hpcups build_x86_64/hpcups -output hpcups_universal
codesign -s - -f hpcups_universal
mkdir -p "$REPO_DIR/bin"
cp hpcups_universal "$REPO_DIR/bin/hpcups"

echo "==> Preparing PPD..."
mkdir -p "$REPO_DIR/ppd"
gunzip -c ppd/hpcups/hp-deskjet_2300_series.ppd.gz \
  | sed 's|\*cupsFilter: "application/vnd.cups-raster 0 hpcups"|*cupsFilter: "application/vnd.cups-raster 0 /Library/Printers/hplip/hpcups"|' \
  > "$REPO_DIR/ppd/HP DeskJet 2300 series hpcups.ppd"

file "$REPO_DIR/bin/hpcups"
echo "Done. Next: sudo sh setup.sh"
