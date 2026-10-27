# MT7601U Wi-Fi for macOS (experimental)

日本語 | [English](README.en.md)

MediaTek **MT7601U** (USB `148f:7601`, 802.11n 2.4 GHz) 用の macOS ユーザー空間 Wi-Fi ドライバです。
Linux の `mt7601u` ドライバを無改造に近い形で、Linux カーネル API 互換層の上で動かします
([rtw89-macos](https://github.com/Long0823-1/rtw89-macos) と同じ方式)。

- 対応: 2.4GHz、WPA2-PSK / オープン、DHCP/IPv6 (RA)、メニューバーアプリ、`mt7601u-wifi` コマンド
- 非対応: WPA3、5GHz、macOS 標準の Wi-Fi 設定への統合 (通信は専用の `utun` インターフェース経由)
- Intel Mac (x86_64) / macOS 26 で動作確認。Apple Silicon は未確認です。**実験的なソフトウェアです。**

## インストール (GUI)

1. [Releases](../../releases) から `MT7601U-WiFi-x.y.pkg` をダウンロード
2. 右クリック →「開く」(署名なしのため)。ウィザードに従う
3. MT7601U を USB に挿す → メニューバーの Wi-Fi アイコンからネットワークを選んで接続

アンインストール: `sudo /usr/local/libexec/mt7601u/uninstall.sh`

## ソースからビルド

```bash
scripts/fetch-firmware.sh      # mt7601u.bin を取得
installer/build-pkg.sh         # dist/MT7601U-WiFi-0.1.pkg を作る (Xcode Command Line Tools が必要)
```

デーモンだけ試す場合:

```bash
cd port && make
RTW89_FW_DIR=../mt7601u ./mt7601ud scan
```

## 使い方

メニューバーのアイコン: 接続状況 (強度)、ネットワーク一覧 (鍵アイコン = パスワード必要)、接続/切断、保存済みネットワークの削除。

コマンド:

```
mt7601u-wifi scan | list | status
mt7601u-wifi connect "SSID"       # パスワードを聞かれ、保存されて自動接続されます
mt7601u-wifi disconnect | forget "SSID" | log | start | stop | restart
```

接続中のデフォルト経路は変更しません。疎通確認: `ping -b utun4 <gateway>`。ログ: `/var/log/mt7601ud.log`。

## 仕組み

`port/host/` のデーモン `mt7601ud` が IOKit で USB を開き、上流 `mt7601u` ドライバ + 自前の mac80211/MLME/WPA2 を実行します。
メニューバーアプリ (`menubar/`, Swift) はデーモンの制御ソケット `/var/run/mt7601ud.sock` と会話します。

## 既知の問題

- チップが固まったとき (USB の突然の切断後など) はデーモンが自動で再起動して初期化し直します。直らない場合は USB を挿し直してください
- ハンドシェイクが失敗する場合、まずパスワードの打ち間違いを確認してください

## ライセンス

GPL-2.0 (`COPYING`)。第三者コードは `THIRD_PARTY.md` を参照。

## Support / 開発支援

開発・保守活動をKo-fiで支援できます。

[Ko-fiで支援する](https://ko-fi.com/long0823)
