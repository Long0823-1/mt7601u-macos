// SPDX-License-Identifier: BSD-3-Clause
// Menu bar app for the mt7601ud daemon: shows the Wi-Fi state, lists networks and connects to them.
// Talks to the daemon's control socket (/var/run/mt7601ud.sock): one command per connection, text/JSON reply.
import Cocoa
import Darwin

let socketPath = ProcessInfo.processInfo.environment["MT7601U_SOCK"] ?? "/var/run/mt7601ud.sock"

// MARK: - control socket client

func control(_ command: String) -> String? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    if fd < 0 { return nil }
    defer { close(fd) }
    var tv = timeval(tv_sec: 4, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(socketPath.utf8CString)
    withUnsafeMutableBytes(of: &addr.sun_path) { raw in
        for (i, b) in bytes.enumerated() where i < raw.count { raw[i] = UInt8(bitPattern: b) }
    }
    let len = socklen_t(MemoryLayout<sockaddr_un>.size)
    let ok = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, len) }
    }
    if ok != 0 { return nil }
    let line = Array((command + "\n").utf8)
    if write(fd, line, line.count) < 0 { return nil }
    var out = Data()
    var buf = [UInt8](repeating: 0, count: 8192)
    while true {
        let n = read(fd, &buf, buf.count)
        if n <= 0 { break }
        out.append(buf, count: n)
    }
    return String(data: out, encoding: .utf8)
}

func hex(_ s: String) -> String { s.utf8.map { String(format: "%02x", $0) }.joined() }

// MARK: - model

struct Status {
    var state = "daemon_down"      // daemon_down, starting, no_adapter, idle, scanning, connecting, connected, failed
    var ssid = ""
    var ip = ""
    var signal = 0
    var channel = 0
    var rxRate = ""
    var error = ""
    var known: [String] = []
}

struct Network {
    let ssid: String
    let signal: Int
    let channel: Int
    let secure: Bool
    let known: Bool
}

func fetchStatus() -> Status {
    guard let reply = control("status"),
          let data = reply.data(using: .utf8),
          let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return Status() }
    var s = Status()
    s.state = j["state"] as? String ?? "idle"
    s.ssid = j["ssid"] as? String ?? ""
    s.ip = j["ip"] as? String ?? ""
    s.signal = j["signal"] as? Int ?? 0
    s.channel = j["channel"] as? Int ?? 0
    s.rxRate = j["rx_rate"] as? String ?? ""
    s.error = j["error"] as? String ?? ""
    s.known = j["known"] as? [String] ?? []
    return s
}

func fetchNetworks() -> [Network] {
    guard let reply = control("list"),
          let data = reply.data(using: .utf8),
          let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
    return arr.compactMap { d in
        guard let ssid = d["ssid"] as? String, !ssid.isEmpty else { return nil }
        return Network(ssid: ssid, signal: d["signal"] as? Int ?? -100, channel: d["channel"] as? Int ?? 0,
                       secure: d["secure"] as? Bool ?? true, known: d["known"] as? Bool ?? false)
    }.sorted { $0.signal > $1.signal }
}

// MARK: - app

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    let queue = DispatchQueue(label: "mt7601u.control")
    var status = Status()
    var networks: [Network] = []
    var lastScan = Date.distantPast
    var menuOpen = false
    var pollTimer: Timer?
    var fastPollUntil = Date.distantPast
    var lastError = ""

    func applicationDidFinishLaunching(_ n: Notification) {
        menu.delegate = self
        item.menu = menu
        refreshIcon()
        rebuildMenu()
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.tick() }
    }

    // MARK: polling

    var tickCount = 0
    func tick() {
        tickCount += 1
        let fast = Date() < fastPollUntil || menuOpen
        if fast || tickCount % 3 == 0 { poll() }
    }

    func poll() {
        queue.async {
            let s = fetchStatus()
            DispatchQueue.main.async { self.apply(s) }
        }
    }

    func apply(_ s: Status) {
        let wasFailed = status.state == "failed"
        status = s
        if s.state == "failed", !wasFailed, !s.error.isEmpty, s.error != lastError {
            lastError = s.error
            showFailure(s.error)
        }
        if s.state == "connected" { lastError = "" }
        refreshIcon()
        if menuOpen { rebuildMenu() }
    }

    func requestScan() {
        lastScan = Date()
        queue.async {
            _ = control("scan")
            Thread.sleep(forTimeInterval: 4.5)
            let n = fetchNetworks()
            DispatchQueue.main.async { self.networks = n; if self.menuOpen { self.rebuildMenu() } }
        }
    }

    func loadNetworks() {
        queue.async {
            let n = fetchNetworks()
            DispatchQueue.main.async { self.networks = n; if self.menuOpen { self.rebuildMenu() } }
        }
    }

    // MARK: icon

    func refreshIcon() {
        guard let button = item.button else { return }
        var symbol = "wifi"
        var level: Double = 0
        var tip = ""
        switch status.state {
        case "connected":
            level = max(0.0, min(1.0, Double(status.signal + 90) / 50.0))
            tip = "\(status.ssid) (\(status.signal) dBm)"
        case "connecting", "scanning", "starting":
            symbol = "wifi.exclamationmark"; tip = "接続中…"
        case "daemon_down":
            symbol = "exclamationmark.triangle"; tip = "デーモンが動いていません"
        case "no_adapter":
            symbol = "wifi.slash"; tip = "アダプタが見つかりません"
        case "failed":
            symbol = "wifi.exclamationmark"; tip = status.error
        default:
            symbol = "wifi.slash"; tip = "未接続"
        }
        var image: NSImage?
        if symbol == "wifi" {
            image = NSImage(systemSymbolName: "wifi", variableValue: level, accessibilityDescription: "Wi-Fi")
        }
        if image == nil { image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Wi-Fi") }
        image?.isTemplate = true
        button.image = image
        button.toolTip = tip
    }

    // MARK: menu

    func menuWillOpen(_ menu: NSMenu) {
        menuOpen = true
        rebuildMenu()
        poll()
        loadNetworks()
        if Date().timeIntervalSince(lastScan) > 20 { requestScan() }
    }

    func menuDidClose(_ menu: NSMenu) { menuOpen = false }

    func disabled(_ title: String) -> NSMenuItem {
        let m = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        m.isEnabled = false
        return m
    }

    func action(_ title: String, _ sel: Selector, _ represented: Any? = nil) -> NSMenuItem {
        let m = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        m.target = self
        m.representedObject = represented
        return m
    }

    func rebuildMenu() {
        menu.removeAllItems()
        switch status.state {
        case "connected":
            menu.addItem(disabled("\(status.ssid) に接続中"))
            menu.addItem(disabled("IP \(status.ip)  ・  \(status.signal) dBm  ・  ch\(status.channel)"))
            if !status.rxRate.isEmpty && status.rxRate != "-" { menu.addItem(disabled("受信 \(status.rxRate)")) }
        case "connecting", "scanning", "starting":
            menu.addItem(disabled(status.state == "starting" ? "起動中…" : "接続中…"))
        case "failed":
            menu.addItem(disabled("接続失敗: \(status.error)"))
        case "no_adapter":
            menu.addItem(disabled("アダプタが見つかりません (USB を確認)"))
        case "daemon_down":
            menu.addItem(disabled("デーモンが動いていません"))
            menu.addItem(disabled("sudo mt7601u-wifi start"))
        default:
            menu.addItem(disabled("未接続"))
        }
        menu.addItem(.separator())

        if status.state != "daemon_down" {
            menu.addItem(disabled("ネットワーク"))
            if networks.isEmpty { menu.addItem(disabled("  検索中…")) }
            for n in networks.prefix(30) {
                let current = status.state == "connected" && status.ssid == n.ssid
                let bars = n.signal > -55 ? "▂▄▆█" : n.signal > -65 ? "▂▄▆" : n.signal > -75 ? "▂▄" : "▂"
                let title = NSMutableAttributedString(string: n.ssid)
                title.append(NSAttributedString(string: "   \(bars) \(n.signal)",
                                                attributes: [.foregroundColor: NSColor.secondaryLabelColor,
                                                             .font: NSFont.menuFont(ofSize: 11)]))
                let m = action("", #selector(selectNetwork(_:)), n.ssid)
                m.attributedTitle = title
                m.state = current ? .on : .off
                if n.secure { m.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "secured") }
                m.indentationLevel = 1
                menu.addItem(m)
            }
            menu.addItem(.separator())
            menu.addItem(action("再スキャン", #selector(rescan)))
            if status.state == "connected" || status.state == "connecting" {
                menu.addItem(action("切断", #selector(disconnect)))
            }
            if !status.known.isEmpty {
                let sub = NSMenu()
                for k in status.known { sub.addItem(action(k, #selector(forget(_:)), k)) }
                let parent = NSMenuItem(title: "保存済みネットワークを削除", action: nil, keyEquivalent: "")
                parent.submenu = sub
                menu.addItem(parent)
            }
        }
        menu.addItem(action("ログを開く", #selector(openLog)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    // MARK: actions

    @objc func rescan() { requestScan() }

    @objc func disconnect() {
        queue.async { _ = control("disconnect"); DispatchQueue.main.async { self.poll() } }
    }

    @objc func forget(_ sender: NSMenuItem) {
        guard let ssid = sender.representedObject as? String else { return }
        queue.async { _ = control("forget \(hex(ssid))"); DispatchQueue.main.async { self.poll() } }
    }

    @objc func openLog() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/var/log/mt7601ud.log"))
    }

    @objc func selectNetwork(_ sender: NSMenuItem) {
        guard let ssid = sender.representedObject as? String,
              let n = networks.first(where: { $0.ssid == ssid }) else { return }
        if status.state == "connected" && status.ssid == ssid { return }
        if !n.secure {
            connect(ssid, psk: nil)
        } else if n.known || status.known.contains(ssid) {
            queue.async { _ = control("use \(hex(ssid))"); DispatchQueue.main.async { self.startedConnecting() } }
        } else {
            // the menu is closing; ask for the password on the next run-loop turn
            DispatchQueue.main.async { self.askPassword(ssid) }
        }
    }

    func askPassword(_ ssid: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "「\(ssid)」のパスワード"
        alert.informativeText = "WPA2 パスフレーズ (8〜63 文字) を入力してください。"
        alert.addButton(withTitle: "接続")
        alert.addButton(withTitle: "キャンセル")
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let psk = field.stringValue
            if psk.utf8.count < 8 || psk.utf8.count > 63 {
                showFailure("パスワードは 8〜63 文字で入力してください")
                return
            }
            connect(ssid, psk: psk)
        }
    }

    func connect(_ ssid: String, psk: String?) {
        queue.async {
            let cmd = "connect \(hex(ssid)) " + (psk.map { hex($0) } ?? "-")
            let reply = control(cmd) ?? "error daemon not reachable"
            DispatchQueue.main.async {
                if reply.hasPrefix("error") { self.showFailure(reply) } else { self.startedConnecting() }
            }
        }
    }

    func startedConnecting() {
        status.state = "connecting"
        lastError = ""
        refreshIcon()
        fastPollUntil = Date().addingTimeInterval(45)
        poll()
    }

    func showFailure(_ message: String) {
        let text: String
        switch message {
        case let m where m.contains("wrong password"): text = "パスワードが違うか、ハンドシェイクに失敗しました。"
        case let m where m.contains("not found"): text = "ネットワークが見つかりません。"
        case let m where m.contains("DHCP"): text = "IP アドレスを取得できませんでした (DHCP)。"
        default: text = message
        }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Wi-Fi に接続できません"
        alert.informativeText = text
        alert.runModal()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
