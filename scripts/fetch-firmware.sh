#!/bin/bash
# Downloads the MT7601U firmware from linux-firmware (not bundled in git).
set -e
D="$(cd "$(dirname "$0")/.." && pwd)/mt7601u"
curl -fL -o "$D/mt7601u.bin" https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/mediatek/mt7601u.bin
ls -l "$D/mt7601u.bin"
