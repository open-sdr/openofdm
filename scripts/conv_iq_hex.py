#!/usr/bin/env python3
"""
Convert an openofdm packed-hex I/Q capture into the two-decimal-column format
dot11_tb.v expects.

The testing_inputs sets are NOT all the same format. Files ending _openwifi.txt
are already "I Q" decimal per line, which is what the bench's
$fscanf("%d %d", ...) reads. The rest - most of conducted/ - are one 8-hex-digit
word per line, packing two signed 16-bit values:

    0012fff9  ->  I = 0x0012 =  18,  Q = 0xfff9 = -7

Feeding a hex file to the bench unconverted does not error; $fscanf simply
fails to match and the run looks like a dead receiver.

    python3 tools/conv_iq_hex.py <in.txt> <out.txt> [--swap]

--swap exchanges I and Q (spectrum conjugate) if a decode fails on the first
attempt and the packing order turns out to be the other way round.
"""
import sys


def s16(v):
    return v - 0x10000 if v & 0x8000 else v


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    swap = "--swap" in sys.argv
    if len(args) != 2:
        sys.exit(__doc__)
    src, dst = args

    n = 0
    with open(src) as fi, open(dst, "w") as fo:
        for line in fi:
            t = line.strip()
            if not t:
                continue
            if len(t) != 8:
                sys.exit("line %d is not 8 hex chars: %r "
                         "(already decimal? use the file directly)" % (n + 1, t))
            w = int(t, 16)
            i, q = s16(w >> 16), s16(w & 0xFFFF)
            if swap:
                i, q = q, i
            fo.write("%d %d\n" % (i, q))
            n += 1
    print("wrote %s: %d samples%s" % (dst, n, " (I/Q swapped)" if swap else ""))


if __name__ == "__main__":
    main()
