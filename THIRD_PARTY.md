# Third-party code

- `mt7601u/src/` — Linux kernel `drivers/net/wireless/mediatek/mt7601u` (GPL-2.0-only). Only `trace.h`/`trace.c` are replaced by stubs
  (tracepoints disabled), `mcu.c`/`init.c` carry small macOS notes (`__APPLE__` power cycle before init).
- `port/compat/` — Linux kernel API compatibility headers (mac80211/cfg80211/usb/skbuff subsets) derived from the Linux kernel (GPL-2.0).
- `port/host/` — userspace mac80211/MLME/WPA2 supplicant, IOKit USB shim and daemon, adapted from
  [Long0823-1/rtw89-macos](https://github.com/Long0823-1/rtw89-macos) (GPL-2.0, parts BSD-3-Clause).
- `mt7601u.bin` firmware (not stored in this repository) — from [linux-firmware](https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/tree/mediatek), MediaTek license (redistribution allowed).
