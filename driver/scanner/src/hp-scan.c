/*
 * hp-scan — minimal standalone frontend for the hpaio SANE backend (HPLIP).
 * Calls the backend directly (static link), without the SANE front-end stack.
 *
 * Usage:
 *   hp-scan [-m Color|Gray|Lineart] [-r dpi] [-d device-uri] [-L] -o out.bmp|out.png|out.jpg
 *
 * Writes BMP itself; converts .png/.jpg/.tiff with system sips.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "sane.h"

/* local status strings instead of sane_strstatus */
static const char *status_str(SANE_Status s)
{
    switch (s) {
    case SANE_STATUS_GOOD: return "ok";
    case SANE_STATUS_UNSUPPORTED: return "unsupported";
    case SANE_STATUS_CANCELLED: return "cancelled";
    case SANE_STATUS_DEVICE_BUSY: return "device busy";
    case SANE_STATUS_INVAL: return "invalid argument";
    case SANE_STATUS_EOF: return "eof";
    case SANE_STATUS_JAMMED: return "paper jam";
    case SANE_STATUS_NO_DOCS: return "no documents";
    case SANE_STATUS_COVER_OPEN: return "cover open";
    case SANE_STATUS_IO_ERROR: return "I/O error";
    case SANE_STATUS_NO_MEM: return "out of memory";
    case SANE_STATUS_ACCESS_DENIED: return "access denied";
    default: return "unknown error";
    }
}

/* hpaio backend entry points (SANE naming) */
extern SANE_Status sane_hpaio_init(SANE_Int *ver, SANE_Auth_Callback auth);
extern void        sane_hpaio_exit(void);
extern SANE_Status sane_hpaio_get_devices(const SANE_Device ***list, SANE_Bool local);
extern SANE_Status sane_hpaio_open(SANE_String_Const name, SANE_Handle *h);
extern void        sane_hpaio_close(SANE_Handle h);
extern const SANE_Option_Descriptor *sane_hpaio_get_option_descriptor(SANE_Handle h, SANE_Int i);
extern SANE_Status sane_hpaio_control_option(SANE_Handle h, SANE_Int i, SANE_Action a, void *v, SANE_Int *info);
extern SANE_Status sane_hpaio_get_parameters(SANE_Handle h, SANE_Parameters *p);
extern SANE_Status sane_hpaio_start(SANE_Handle h);
extern SANE_Status sane_hpaio_read(SANE_Handle h, SANE_Byte *buf, SANE_Int max, SANE_Int *len);
extern void        sane_hpaio_cancel(SANE_Handle h);

static void die(const char *msg, SANE_Status st)
{
    fprintf(stderr, "hp-scan: %s%s%s\n", msg,
            st == SANE_STATUS_GOOD ? "" : ": ",
            st == SANE_STATUS_GOOD ? "" : status_str(st));
    exit(1);
}

/* find option index by name */
static SANE_Int find_option(SANE_Handle h, const char *name)
{
    SANE_Int count = 0;
    if (sane_hpaio_control_option(h, 0, SANE_ACTION_GET_VALUE, &count, 0) != SANE_STATUS_GOOD)
        return -1;
    for (SANE_Int i = 1; i < count; i++) {
        const SANE_Option_Descriptor *d = sane_hpaio_get_option_descriptor(h, i);
        if (d && d->name && strcmp(d->name, name) == 0)
            return i;
    }
    return -1;
}

static void set_string_option(SANE_Handle h, const char *name, const char *value)
{
    SANE_Int i = find_option(h, name);
    if (i < 0) { fprintf(stderr, "hp-scan: option '%s' not found, skipping\n", name); return; }
    char buf[64];
    snprintf(buf, sizeof(buf), "%s", value);
    SANE_Status st = sane_hpaio_control_option(h, i, SANE_ACTION_SET_VALUE, buf, 0);
    if (st != SANE_STATUS_GOOD)
        fprintf(stderr, "hp-scan: failed to set %s=%s: %s\n", name, value, status_str(st));
}

static void set_int_option(SANE_Handle h, const char *name, int value)
{
    SANE_Int i = find_option(h, name);
    if (i < 0) { fprintf(stderr, "hp-scan: option '%s' not found, skipping\n", name); return; }
    const SANE_Option_Descriptor *d = sane_hpaio_get_option_descriptor(h, i);
    SANE_Word w = (d && d->type == SANE_TYPE_FIXED) ? SANE_FIX((double)value) : value;
    SANE_Status st = sane_hpaio_control_option(h, i, SANE_ACTION_SET_VALUE, &w, 0);
    if (st != SANE_STATUS_GOOD)
        fprintf(stderr, "hp-scan: failed to set %s=%d: %s\n", name, value, status_str(st));
}

/* --- BMP (24-bit, bottom-up, BGR) --- */
static void put32(FILE *f, unsigned v){ fputc(v,f); fputc(v>>8,f); fputc(v>>16,f); fputc(v>>24,f); }
static void put16(FILE *f, unsigned v){ fputc(v,f); fputc(v>>8,f); }

static int write_bmp(const char *path, const unsigned char *img, int w, int h, int channels)
{
    FILE *f = fopen(path, "wb");
    if (!f) return -1;
    int stride = (w * 3 + 3) & ~3;
    unsigned size = 54 + (unsigned)stride * h;
    fputc('B', f); fputc('M', f);
    put32(f, size); put32(f, 0); put32(f, 54);
    put32(f, 40); put32(f, w); put32(f, h);
    put16(f, 1); put16(f, 24); put32(f, 0); put32(f, (unsigned)stride * h);
    put32(f, 2835); put32(f, 2835); put32(f, 0); put32(f, 0);
    unsigned char *row = calloc(1, stride);
    for (int y = h - 1; y >= 0; y--) {
        const unsigned char *src = img + (size_t)y * w * channels;
        for (int x = 0; x < w; x++) {
            unsigned char r, g, b;
            if (channels == 3) { r = src[3*x]; g = src[3*x+1]; b = src[3*x+2]; }
            else               { r = g = b = src[x]; }
            row[3*x] = b; row[3*x+1] = g; row[3*x+2] = r;
        }
        fwrite(row, 1, stride, f);
    }
    free(row);
    fclose(f);
    return 0;
}

int main(int argc, char **argv)
{
    const char *mode = "Color", *out = NULL, *device = NULL;
    int dpi = 300, list_only = 0, opt;

    while ((opt = getopt(argc, argv, "m:r:d:o:Lh")) != -1) {
        switch (opt) {
        case 'm': mode = optarg; break;
        case 'r': dpi = atoi(optarg); break;
        case 'd': device = optarg; break;
        case 'o': out = optarg; break;
        case 'L': list_only = 1; break;
        default:
            fprintf(stderr, "Usage: hp-scan [-m Color|Gray|Lineart] [-r dpi] [-d uri] [-L] -o out.{bmp,png,jpg}\n");
            return 2;
        }
    }

    SANE_Status st = sane_hpaio_init(NULL, NULL);
    if (st != SANE_STATUS_GOOD) die("backend init", st);

    const SANE_Device **devs = NULL;
    if (!device || list_only) {
        st = sane_hpaio_get_devices(&devs, SANE_TRUE);
        if (st != SANE_STATUS_GOOD) die("device discovery", st);
        if (list_only) {
            int found = 0;
            for (int i = 0; devs && devs[i]; i++) {
                printf("%s  (%s %s)\n", devs[i]->name, devs[i]->vendor, devs[i]->model);
                found = 1;
            }
            if (!found) fprintf(stderr, "hp-scan: no scanners found\n");
            sane_hpaio_exit();
            return found ? 0 : 1;
        }
        if (!devs || !devs[0]) die("no scanners found (is the printer on and connected via USB?)", SANE_STATUS_GOOD);
        device = devs[0]->name;
    }
    if (!out) die("output file required (-o scan.png)", SANE_STATUS_GOOD);

    SANE_Handle h;
    st = sane_hpaio_open(device, &h);
    if (st != SANE_STATUS_GOOD) die("open device", st);

    set_string_option(h, "mode", mode);
    set_int_option(h, "resolution", dpi);

    st = sane_hpaio_start(h);
    if (st != SANE_STATUS_GOOD) die("start scan", st);

    SANE_Parameters p;
    st = sane_hpaio_get_parameters(h, &p);
    if (st != SANE_STATUS_GOOD) die("scan parameters", st);
    int channels = (p.format == SANE_FRAME_RGB) ? 3 : 1;
    if (p.depth != 8) die("only 8-bit Color/Gray modes are supported", SANE_STATUS_GOOD);
    fprintf(stderr, "hp-scan: %dx%d, %s, %d dpi\n",
            p.pixels_per_line, p.lines, channels == 3 ? "RGB" : "Gray", dpi);

    size_t cap = (size_t)p.bytes_per_line * (p.lines > 0 ? p.lines : 1);
    size_t used = 0;
    unsigned char *img = malloc(cap ? cap : 1);
    unsigned char buf[65536];
    SANE_Int n;
    for (;;) {
        st = sane_hpaio_read(h, buf, sizeof(buf), &n);
        if (st == SANE_STATUS_EOF) break;
        if (st != SANE_STATUS_GOOD) die("read data", st);
        if (used + n > cap) { cap = (used + n) * 2; img = realloc(img, cap); }
        memcpy(img + used, buf, n); used += n;
    }
    sane_hpaio_cancel(h);
    sane_hpaio_close(h);
    sane_hpaio_exit();

    int lines = p.lines > 0 ? p.lines : (int)(used / p.bytes_per_line);

    /* write BMP; convert .png/.jpg/.tiff with sips */
    const char *ext = strrchr(out, '.');
    int need_convert = ext && (strcasecmp(ext, ".png") == 0 || strcasecmp(ext, ".jpg") == 0 ||
                               strcasecmp(ext, ".jpeg") == 0 || strcasecmp(ext, ".tiff") == 0);
    char bmp_path[4096];
    if (need_convert) snprintf(bmp_path, sizeof(bmp_path), "%s.tmp.bmp", out);
    else              snprintf(bmp_path, sizeof(bmp_path), "%s", out);

    if (write_bmp(bmp_path, img, p.pixels_per_line, lines, channels) != 0)
        die("write file", SANE_STATUS_GOOD);

    if (need_convert) {
        const char *fmt = (strcasecmp(ext, ".png") == 0) ? "png" :
                          (strcasecmp(ext, ".tiff") == 0) ? "tiff" : "jpeg";
        char cmd[9000];
        snprintf(cmd, sizeof(cmd), "/usr/bin/sips -s format %s '%s' --out '%s' >/dev/null 2>&1",
                 fmt, bmp_path, out);
        if (system(cmd) != 0) die("sips conversion", SANE_STATUS_GOOD);
        unlink(bmp_path);
    }
    fprintf(stderr, "hp-scan: done — %s\n", out);
    free(img);
    return 0;
}
