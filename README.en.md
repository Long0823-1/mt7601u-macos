# MT7601U Wi-Fi for macOS (experimental)

[日本語](README.md) | English

A userspace macOS Wi-Fi driver for MediaTek **MT7601U** USB adapters (`148f:7601`, 802.11n, 2.4 GHz).
It runs the upstream Linux `mt7601u` driver almost unmodified on a Linux-kernel-API compatibility layer
(same approach as [rtw89-macos](https://github.com/Long0823-1/rtw89-macos)).

- Supported: 2.4 GHz, WPA2-PSK / open networks, DHCP and IPv6, menu bar app, `mt7601u-wifi` command
- Not supported: WPA3, 5 GHz, integration into the macOS Wi-Fi settings (traffic goes through a dedicated `utun` interface)
- Tested on an Intel Mac / macOS 26 only. **Experimental software.**

## Install (GUI)

1. Download `MT7601U-WiFi-x.y.pkg` from [Releases](../../releases)
2. Right-click → Open (the package is unsigned) and follow the installer
3. Plug in the MT7601U → pick a network from the Wi-Fi icon in the menu bar

The installer and the menu bar app follow the system language (Japanese / English).

Uninstall: `sudo /usr/local/libexec/mt7601u/uninstall.sh`

## Build from source

```bash
scripts/fetch-firmware.sh      # download mt7601u.bin
installer/build-pkg.sh         # builds dist/MT7601U-WiFi-0.1.pkg (needs Xcode Command Line Tools)
```

Daemon only:

```bash
cd port && make
RTW89_FW_DIR=../mt7601u ./mt7601ud scan
```

## Usage

Menu bar icon: connection status (signal strength), network list (lock = password required), connect / disconnect, forget saved networks.

Command line:

```
mt7601u-wifi scan | list | status
mt7601u-wifi connect "SSID"       # asks for the password, saves it and auto-connects later
mt7601u-wifi disconnect | forget "SSID" | log | start | stop | restart
```

The default route is not changed. Check connectivity with `ping -b utun4 <gateway>`. Log: `/var/log/mt7601ud.log`.
Set `MT7601U_LANG=en` or `ja` to force the language of the command line messages.

## How it works

The daemon `mt7601ud` (`port/host/`) opens the USB device through IOKit and runs the upstream `mt7601u` driver together with its own
mac80211 / MLME / WPA2 implementation. The menu bar app (`menubar/`, Swift) talks to the daemon over `/var/run/mt7601ud.sock`.

## Known issues

- If the chip gets wedged (e.g. after a sudden USB disconnect) the daemon restarts itself and re-initializes the adapter. If that does not help, replug the adapter.
- If the handshake fails, first check the password for typos.

## License

GPL-2.0 (`COPYING`). See `THIRD_PARTY.md` for third-party code.
