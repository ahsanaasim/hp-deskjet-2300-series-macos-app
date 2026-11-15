#!/bin/sh
# ============================================================
# Воспроизводимая сборка автономного hp-scan (universal binary)
# и SANE-бэкенда libsane-hpaio (arm64) из официальных исходников.
#
# Использование:  sh build-scanner.sh [рабочая-папка]
# Результат:      <папка>/out/hp-scan, <папка>/out/libsane-hpaio.1.dylib
#
# Требуется только Xcode Command Line Tools (clang). Никакого Homebrew.
# ============================================================
set -e

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="${1:-$PWD/scanner-build}"
mkdir -p "$WORK/out"
cd "$WORK"

HPLIP=hplip-3.25.2
LIBUSB=libusb-1.0.30

# --- 1. Исходники ------------------------------------------------
[ -f $HPLIP.tar.gz ] || curl -sL -o $HPLIP.tar.gz \
  "https://downloads.sourceforge.net/project/hplip/hplip/3.25.2/$HPLIP.tar.gz"
[ -d $HPLIP ] || tar xzf $HPLIP.tar.gz
[ -f $LIBUSB.tar.bz2 ] || curl -sL -o $LIBUSB.tar.bz2 \
  "https://github.com/libusb/libusb/releases/download/v1.0.30/$LIBUSB.tar.bz2"
[ -d $LIBUSB ] || tar xjf $LIBUSB.tar.bz2

# --- 2. libusb: статическая universal-библиотека -----------------
if [ ! -f $LIBUSB/libusb/.libs/libusb-1.0.a ]; then
  ( cd $LIBUSB && \
    ./configure --disable-shared --enable-static --disable-udev \
      CFLAGS="-O2 -arch arm64 -arch x86_64" >/dev/null && \
    make -j8 >/dev/null )
fi

# --- 3. Патчи HPLIP под macOS ------------------------------------
cd $HPLIP
mkdir -p shim

# 3a. malloc.h -> stdlib.h
printf '#pragma once\n#include <stdlib.h>\n' > shim/malloc.h

# 3b. выключить OrbliteScan (легаси-сканеры Mac; конфликт типов
#     MacCommon.h с современным CoreFoundation). LEDM его не использует.
sed -i.bak 's|#include "orblitei.h"|#include "orblite.h"|' scan/sane/hpaio.c scan/sane/hpaio.h

cat > shim/orblite_min.h <<'EOF'
/* Минимальные объявления из orblitei.h (ветка ORBLITE недостижима) */
#ifndef ORBLITE_MIN_H
#define ORBLITE_MIN_H
#include "sane.h"
typedef enum {
    optCount = 0,
    optTLX, optTLY, optBRX, optBRY,
    optResolution, optMode, optSource, optPaperSize, optMultipick,
    optLast,
    optGammaTableRed, optGammaTableGreen, optGammaTableBlue,
} EOptionIndex;
struct t_SANE {
    char *tag;
    SANE_Option_Descriptor* Options;
};
#endif
EOF

cat > shim/orblite_stub.c <<'EOF'
/* Заглушки Orblite (scan-type 10). init/get_devices обязаны возвращать
   GOOD, иначе SANE отбрасывает весь бэкенд при инициализации. */
#include "sane.h"
SANE_Status orblite_init (SANE_Int *v, SANE_Auth_Callback a){ return SANE_STATUS_GOOD; }
SANE_Status orblite_get_devices (const SANE_Device ***l, SANE_Bool lo){ return SANE_STATUS_GOOD; }
void orblite_exit (void){}
SANE_Status orblite_open (SANE_String_Const d, SANE_Handle *h){ return SANE_STATUS_UNSUPPORTED; }
void orblite_close (SANE_Handle h){}
const SANE_Option_Descriptor * orblite_get_option_descriptor (SANE_Handle h, SANE_Int o){ return 0; }
SANE_Status orblite_control_option (SANE_Handle h, SANE_Int o, SANE_Action a, void *v, SANE_Int *i){ return SANE_STATUS_UNSUPPORTED; }
SANE_Status orblite_get_parameters (SANE_Handle h, SANE_Parameters *p){ return SANE_STATUS_UNSUPPORTED; }
SANE_Status orblite_start (SANE_Handle h){ return SANE_STATUS_UNSUPPORTED; }
SANE_Status orblite_read (SANE_Handle h, SANE_Byte *d, SANE_Int m, SANE_Int *l){ return SANE_STATUS_UNSUPPORTED; }
void orblite_cancel (SANE_Handle h){}
EOF

cp "$SRC_DIR/hp-scan.c" shim/hp-scan.c

# --- 4. Компиляция (обе архитектуры) -----------------------------
HPMUD_SRC="io/hpmud/mlc.c io/hpmud/model.c io/hpmud/pml.c io/hpmud/dot4.c io/hpmud/jd.c io/hpmud/pp.c io/hpmud/musb.c common/utils.c"
IP_SRC="ip/xconvolve.c ip/xfax.c ip/xgrayout.c ip/xjpg_dct.c ip/xjpg_fix.c ip/xpad.c ip/xrotate.c ip/xskel.c ip/xtiff.c ip/ipmain.c ip/xchgbpp.c ip/xcrop.c ip/xgamma.c ip/xjpg_dec.c ip/xjpg_huf.c ip/xpcx.c ip/xsaturation.c ip/xtable.c ip/xtonemap.c ip/xbi2gray.c ip/xcolrspc.c ip/xfakemono.c ip/xgray2bi.c ip/xinvert.c ip/xjpg_enc.c ip/xmatrix.c ip/xpnm.c ip/xscale.c ip/xthumb.c ip/xyxtract.c"
SCAN_SRC="scan/sane/mfpdtf.c scan/sane/pml.c scan/sane/scl.c scan/sane/io.c scan/sane/common.c scan/sane/sanei_init_debug.c scan/sane/marvell.c scan/sane/soapht.c scan/sane/soap.c scan/sane/xml.c scan/sane/ledm.c scan/sane/bb_ledm.c scan/sane/http.c scan/sane/escl.c"

for ARCH in arm64 x86_64; do
  OUT="obj-$ARCH"
  mkdir -p "$OUT"

  cc_one() {
    clang -arch "$ARCH" -O2 -w -fPIC \
      -DVERSION='"3.25.2"' -DCONFDIR='"/etc/hp"' \
      -include unistd.h \
      -I. -Icommon -Iip -Iio/hpmud -Iprotocol -Iscan/sane -Ishim \
      -I"../$LIBUSB/libusb" "$@"
  }

  for f in $HPMUD_SRC $IP_SRC $SCAN_SRC; do
    cc_one -c "$f" -o "$OUT/$(echo "$f" | tr '/.' '__').o"
  done
  # особые случаи:
  #  - sysdump определён и в hpmud.c, и в scan/common.c — переименовываем
  #  - hpaio.c нужны объявления из orblite_min.h
  #  - sclpml.c не включает sys/time.h сам
  cc_one -Dsysdump=hpmud_sysdump -c io/hpmud/hpmud.c -o "$OUT/hpmud.o"
  cc_one -include shim/orblite_min.h -c scan/sane/hpaio.c -o "$OUT/hpaio.o"
  cc_one -include sys/time.h -c scan/sane/sclpml.c -o "$OUT/sclpml.o"
  cc_one -c shim/orblite_stub.c -o "$OUT/orblite_stub.o"
  cc_one -c shim/hp-scan.c -o "$OUT/hp-scan.o"

  clang -arch "$ARCH" -o "$OUT/hp-scan" "$OUT"/*.o \
    "../$LIBUSB/libusb/.libs/libusb-1.0.a" \
    -lcups -lpthread -ldl -lz \
    -framework IOKit -framework CoreFoundation -framework Security
  echo "built: $ARCH"
done

# --- 5. Universal + подпись --------------------------------------
lipo -create obj-arm64/hp-scan obj-x86_64/hp-scan -output "$WORK/out/hp-scan"
codesign -s - -f "$WORK/out/hp-scan"

# --- 6. (опционально) SANE-бэкенд для scanimage, arm64 -----------
DYLIB_OBJS="$(ls obj-arm64/*.o | grep -v hp-scan)"
clang -arch arm64 -dynamiclib -o "$WORK/out/libsane-hpaio.1.dylib" $DYLIB_OBJS \
  "../$LIBUSB/libusb/.libs/libusb-1.0.a" \
  -lcups -lpthread -ldl -lz \
  -framework IOKit -framework CoreFoundation -framework Security \
  -install_name /Library/Printers/hplip/sane/libsane-hpaio.1.dylib
codesign -s - -f "$WORK/out/libsane-hpaio.1.dylib"

cp data/models/models.dat "$WORK/out/models.dat"
echo ""
echo "Готово:"
lipo -info "$WORK/out/hp-scan"
ls -la "$WORK/out/"
