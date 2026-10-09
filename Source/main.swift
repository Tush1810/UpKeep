import AppKit
import Carbon

func durationSeconds(_ input: String, unit: Int) -> Int? {
    guard let value = Double(input.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite, value > 0 else { return nil }
    let seconds = (value * (unit == 1 ? 3600 : 60)).rounded()
    guard seconds >= 1, seconds <= 31_536_000 else { return nil }
    return Int(seconds)
}

func durationNumber(_ value: Double) -> String {
    var text = String(format: "%.6f", value)
    while text.last == "0" { text.removeLast() }
    if text.last == "." { text.removeLast() }
    return text
}

func remainingTime(_ seconds: Int, compact: Bool) -> String {
    let value = max(1, seconds)
    if value < 60 { return compact ? "\(value)s" : "\(value) \(value == 1 ? "second" : "seconds") remaining" }
    if value < 3600 {
        return compact ? String(format: "%d:%02d", value / 60, value % 60) : "\(value / 60)m \(value % 60)s remaining"
    }
    if value < 86400 {
        let hours = value / 3600, minutes = value % 3600 / 60
        return compact ? "\(hours)h \(minutes)m" : "\(hours)h \(minutes)m \(value % 60)s remaining"
    }
    let days = value / 86400, hours = value % 86400 / 3600
    return compact ? "\(days)d \(hours)h" : "\(days)d \(hours)h \(value % 3600 / 60)m remaining"
}

func sessionEnd(_ deadline: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.timeStyle = .short
    formatter.dateStyle = calendar.isDate(deadline, inSameDayAs: now) ? .none : .medium
    return "Ends at \(formatter.string(from: deadline))"
}

enum SessionMode {
    case off, timed, unlimited, displayAwake

    var title: String {
        switch self {
        case .off: return "Off"
        case .timed: return "Timed"
        case .unlimited: return "Infinite"
        case .displayAwake: return "Timed + display"
        }
    }

    var color: NSColor {

        switch self {
        case .off: return .labelColor
        case .timed: return NSColor(srgbRed: 245 / 255.0, green: 166 / 255.0, blue: 35 / 255.0, alpha: 1)
        case .unlimited: return NSColor(srgbRed: 167 / 255.0, green: 139 / 255.0, blue: 250 / 255.0, alpha: 1)
        case .displayAwake: return NSColor(srgbRed: 34 / 255.0, green: 211 / 255.0, blue: 238 / 255.0, alpha: 1)
        }
    }
}

func coffeeIcon(mode: SessionMode, size: CGFloat = 22) -> NSImage {
    let active = mode != .off
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let scale = size / 22
        let transform = NSAffineTransform()
        transform.scale(by: scale)
        transform.concat()
        mode.color.set()
        let cup = NSBezierPath(roundedRect: NSRect(x: 3, y: 5, width: 12, height: 10), xRadius: 3, yRadius: 3)
        cup.lineWidth = 1.6
        active ? cup.fill() : cup.stroke()
        let handle = NSBezierPath(ovalIn: NSRect(x: 13, y: 7, width: 6, height: 6))
        handle.lineWidth = 1.6
        handle.stroke()
        let saucer = NSBezierPath()
        saucer.move(to: NSPoint(x: 2, y: 3)); saucer.line(to: NSPoint(x: 17, y: 3))
        saucer.lineWidth = 1.6; saucer.lineCapStyle = .round; saucer.stroke()
        for x: CGFloat in [6, 10, 14] {
            let steam = NSBezierPath()
            steam.move(to: NSPoint(x: x, y: 17))
            steam.curve(to: NSPoint(x: x, y: 21), controlPoint1: NSPoint(x: x-2, y: 18), controlPoint2: NSPoint(x: x+2, y: 20))
            steam.lineWidth = 1.3; steam.lineCapStyle = .round; steam.stroke()
        }
        return true
    }
    image.isTemplate = !active
    return image
}

// A read-only status card; actions stay native NSMenuItems for keyboard navigation.
final class MenuStatusCard: NSView {
    let coffee = NSImageView(frame: NSRect(x: 22, y: 70, width: 30, height: 30))
    let brand = NSTextField(labelWithString: "Upkeep")
    let modeLabel = NSTextField(labelWithString: "Off")
    let countdown = NSTextField(labelWithString: "Ready when you are")
    let detail = NSTextField(labelWithString: "")
    let endLabel = NSTextField(labelWithString: "")
    private var mode: SessionMode = .off
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 340, height: 144))
        coffee.frame.origin.y += 22
        brand.frame = NSRect(x: 66, y: 106, width: 252, height: 22)
        brand.font = .systemFont(ofSize: 17, weight: .semibold)
        modeLabel.frame = NSRect(x: 66, y: 87, width: 252, height: 17)
        modeLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        countdown.frame = NSRect(x: 22, y: 53, width: 296, height: 27)
        countdown.cell?.wraps = false
        countdown.cell?.isScrollable = false
        endLabel.frame = NSRect(x: 22, y: 31, width: 296, height: 17)
        endLabel.font = .systemFont(ofSize: 11); endLabel.textColor = .secondaryLabelColor
        detail.frame = NSRect(x: 22, y: 11, width: 296, height: 17)
        detail.font = .systemFont(ofSize: 11); detail.textColor = .secondaryLabelColor
        for view in [coffee, brand, modeLabel, countdown, endLabel, detail] { addSubview(view) }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func update(mode: SessionMode, deadline: Date?, seconds: Int) {
        self.mode = mode
        coffee.image = coffeeIcon(mode: mode, size: 30)
        modeLabel.stringValue = mode.title.uppercased()
        modeLabel.textColor = mode == .off ? .secondaryLabelColor : mode.color
        countdown.font = mode == .off ? .systemFont(ofSize: 17, weight: .medium) : .monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        endLabel.stringValue = ""
        if mode == .off {
            countdown.stringValue = "Ready when you are"
            detail.stringValue = "Default session · \(durationNumber(Double(seconds) / 60)) min"
        } else if let deadline {
            let remaining = max(1, Int(ceil(deadline.timeIntervalSinceNow)))
            countdown.stringValue = remainingTime(remaining, compact: false)
            endLabel.stringValue = sessionEnd(deadline)
            detail.stringValue = mode == .displayAwake ? "Mac + display stay awake" : "Mac stays awake · display can sleep"
        } else {
            countdown.stringValue = "∞  No time limit"
            detail.stringValue = "Mac stays awake · display can sleep"
        }
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        (mode == .off ? NSColor.controlBackgroundColor.withAlphaComponent(0.55) : mode.color.withAlphaComponent(0.08)).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 4), xRadius: 10, yRadius: 10).fill()
    }
}
func menuSymbol(_ name: String, color: NSColor = .labelColor) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
}

enum SessionError: LocalizedError {
    case couldNotStop
    var errorDescription: String? { "The previous session could not be stopped. No replacement was started." }
}

final class Session {
    var process: Process?
    private var expiryTimer: Timer?
    var deadline: Date?
    var keepsDisplayAwake = false
    var changed: (() -> Void)?
    var running: Bool { process?.isRunning == true }
    var mode: SessionMode {
        guard running else { return .off }
        return keepsDisplayAwake ? .displayAwake : deadline == nil ? .unlimited : .timed
    }
    func start(seconds: Int?, keepDisplayAwake: Bool = false) throws {
        precondition(Thread.isMainThread, "Session changes must run on the main thread")
        try stop()
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        child.arguments = (keepDisplayAwake ? ["-di"] : []) + (seconds.map { ["-t", String(max(1, $0))] } ?? []) + ["-w", String(ProcessInfo.processInfo.processIdentifier)]
        child.terminationHandler = { [weak self, weak child] _ in
            DispatchQueue.main.async {
                guard let self, self.process === child else { return }
                self.expiryTimer?.invalidate(); self.expiryTimer = nil
                self.process = nil; self.deadline = nil; self.keepsDisplayAwake = false; self.changed?()
            }
        }
        try child.run()
        process = child; deadline = seconds.map { Date().addingTimeInterval(Double($0)) }
        keepsDisplayAwake = keepDisplayAwake
        if let deadline {
            let timer = Timer(fire: deadline, interval: 0, repeats: false) { [weak self, weak child] _ in
                guard let self, self.process === child else { return }
                try? self.stop()
            }
            expiryTimer = timer; RunLoop.main.add(timer, forMode: .common)
        }
        changed?()
    }
    func select(_ target: SessionMode, seconds: Int, restart: Bool = false) throws {
        precondition(Thread.isMainThread, "Session changes must run on the main thread")
        if target == .off { try stop(); return }
        if target == mode && !restart { return }
        if target == .unlimited { try start(seconds: nil); return }
        try start(seconds: seconds, keepDisplayAwake: target == .displayAwake)
    }
    func stop() throws {
        precondition(Thread.isMainThread, "Session changes must run on the main thread")
        if let child = process, child.isRunning {
            child.terminate()
            waitForExit(child, timeout: 0.25)
            if child.isRunning {
                // Only signal the child owned by this Session, never other caffeinate processes.
                kill(child.processIdentifier, SIGKILL)
                waitForExit(child, timeout: 0.75)
            }
            guard !child.isRunning else { throw SessionError.couldNotStop }
        }
        expiryTimer?.invalidate(); expiryTimer = nil
        process = nil; deadline = nil; keepsDisplayAwake = false
        changed?()
    }
    private func waitForExit(_ child: Process, timeout: TimeInterval) {
        let end = ProcessInfo.processInfo.systemUptime + timeout
        while child.isRunning && ProcessInfo.processInfo.systemUptime < end {
            Thread.sleep(forTimeInterval: 0.005)
        }
    }

}

// Two complete Control taps; typing, mouse clicks, chords, or holds cancel the sequence.
struct DoubleControlDetector {
    var heldKey: Int?
    var pressedAt = 0.0
    var lastRelease: Double?
    mutating func reset() { heldKey = nil; lastRelease = nil }
    mutating func flags(key: Int, down: Bool, otherModifier: Bool, time: Double) -> Bool {
        guard (key == 59 || key == 62), !otherModifier else { reset(); return false }
        if down {
            guard heldKey == nil else { reset(); return false }
            heldKey = key; pressedAt = time
            return false
        }
        guard heldKey == key else { reset(); return false }
        heldKey = nil
        guard time - pressedAt <= 0.45 else { reset(); return false }
        if let previous = lastRelease, pressedAt - previous <= 0.45 {
            lastRelease = nil
            return true
        }
        lastRelease = time
        return false
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    let session = Session()
    var preferences = UserDefaults.standard
    var item: NSStatusItem!
    let menu = NSMenu()
    var menuCard: MenuStatusCard?
    var timer: Timer?
    var externalCount = 0
    var scanPending = false
    var controlDetector = DoubleControlDetector()
    var settingsChordHeld = false
    var eventTap: CFMachPort?
    var tapSource: CFRunLoopSource?
    var localMonitor: Any?
    var enableButton: NSButton?
    var window: NSWindow?
    var durationField: NSTextField!
    var durationUnit: NSPopUpButton!
    var displayedUnit = 0
    var shortcutLabel: NSTextField!
    var errorLabel: NSTextField!
    var permissionLabel: NSTextField?
    var stateLabel: NSTextField?
    var settingsIcon: NSImageView?
    var startButton: NSButton?
    var seconds: Int { preferences.integer(forKey: "duration") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        preferences.register(defaults: ["duration": 7200])
        if seconds < 1 || seconds > 31_536_000 { preferences.set(7200, forKey: "duration") }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "BrewCoffee"
        menu.delegate = self; item.menu = menu
        session.changed = { [weak self] in self?.refresh() }
        installLocalShortcutMonitor()
        startShortcutMonitor()
        refresh(); scanExternal()
        if CommandLine.arguments.contains("--settings") { showSettings(nil) }
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refresh(); self?.scanExternal(); self?.startShortcutMonitor() }
        RunLoop.main.add(timer!, forMode: .common)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(nil); return true }
    func handleShortcutEvent(type: CGEventType, key: Int, flags: CGEventFlags, time: Double, repeated: Bool = false) {
        let control = flags.contains(.maskControl)
        let other = !flags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskSecondaryFn]).isEmpty
        if type == .flagsChanged {
            let chord = control && flags.contains(.maskShift) && flags.intersection([.maskCommand, .maskAlternate, .maskSecondaryFn]).isEmpty
            let activated = chord && !settingsChordHeld && [59, 62, 56, 60].contains(key)
            settingsChordHeld = chord
            if activated {
                controlDetector.reset()
                DispatchQueue.main.async { [weak self] in self?.showSettings(nil) }
                return
            }
        }
        if type == .keyDown && key == 34 && control && !other && !repeated {
            controlDetector.reset()
            DispatchQueue.main.async { [weak self] in self?.startUnlimited(nil) }
            return
        }
        if type == .keyDown && key == 2 && control && !other && !repeated {
            controlDetector.reset()
            DispatchQueue.main.async { [weak self] in self?.startDisplayAwake(nil) }
            return
        }
        guard type == .flagsChanged else { controlDetector.reset(); return }
        if controlDetector.flags(key: key, down: control, otherModifier: other, time: time) {
            DispatchQueue.main.async { [weak self] in self?.toggle(nil) }
        }
    }
    func installLocalShortcutMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.eventTap == nil else { return event }
            let type: CGEventType = event.type == .flagsChanged ? .flagsChanged : event.type == .keyDown ? .keyDown : .leftMouseDown
            self.handleShortcutEvent(type: type, key: Int(event.keyCode), flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)), time: event.timestamp, repeated: event.type == .keyDown && event.isARepeat)
            return event
        }
    }
    func startShortcutMonitor() {
        guard eventTap == nil, CGPreflightListenEventAccess() else { return }
        let mask = [CGEventType.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown].reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let app = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                app.controlDetector.reset()
                if let tap = app.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            } else {
                app.handleShortcutEvent(type: type, key: Int(event.getIntegerValueField(.keyboardEventKeycode)), flags: event.flags, time: Double(event.timestamp) / 1_000_000_000, repeated: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        eventTap = tap; controlDetector.reset()
        tapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        refresh()
    }
    @objc func enableShortcuts(_ sender: Any?) {
        if CGPreflightListenEventAccess() { startShortcutMonitor(); refresh(); return }
        _ = CGRequestListenEventAccess()
        errorLabel.stringValue = "Enable Upkeep in Input Monitoring, then reopen Upkeep."
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }
    func scanExternal() {
        guard !scanPending else { return }; scanPending = true
        let ownPID = session.process?.processIdentifier
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let ps = Process(); let pipe = Pipe()
            ps.executableURL = URL(fileURLWithPath: "/bin/ps"); ps.arguments = ["-axo", "pid=,comm="]
            ps.standardOutput = pipe; ps.standardError = FileHandle.nullDevice
            var count: Int? = nil
            do {
                try ps.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile(); ps.waitUntilExit()
                if ps.terminationStatus == 0 {
                    count = String(decoding: data, as: UTF8.self).split(separator: "\n").filter { line in
                        let parts = line.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
                        guard parts.count == 2, let pid = Int32(parts[0]), pid != ownPID else { return false }
                        return (String(parts[1]) as NSString).lastPathComponent == "caffeinate"
                    }.count
                }
            } catch {}
            let found = count
            DispatchQueue.main.async {
                guard let self else { return }; self.scanPending = false
                if let found { self.externalCount = found }; self.refresh()
            }
        }
    }
    func refresh() {
        menuCard?.update(mode: session.mode, deadline: session.deadline, seconds: seconds)
        let active = session.running
        stateLabel?.stringValue = active ? (session.keepsDisplayAwake ? "Upkeep active · display awake" : session.deadline == nil ? "Upkeep active · unlimited" : "Upkeep session active") : "Upkeep is off"
        stateLabel?.textColor = active ? session.mode.color : .secondaryLabelColor
        startButton?.title = session.running ? "Stop Upkeep" : "Start Upkeep"
        enableButton?.title = eventTap == nil ? "Enable for all apps…" : "Enabled for all apps ✓"
        enableButton?.isEnabled = eventTap == nil
        permissionLabel?.stringValue = eventTap == nil ? "Input Monitoring needed for other apps." : "Shortcuts are ready in every app."
        item.button?.image = coffeeIcon(mode: session.mode)
        settingsIcon?.image = coffeeIcon(mode: session.mode, size: 48)
        if session.running, let deadline = session.deadline {
            let remaining = max(1, Int(ceil(deadline.timeIntervalSinceNow)))
            item.button?.title = " " + remainingTime(remaining, compact: true)
            item.button?.toolTip = "Upkeep active · " + remainingTime(remaining, compact: false) + " · " + sessionEnd(deadline) + (session.keepsDisplayAwake ? " · display awake" : "") + (externalCount > 0 ? " · external caffeinate also running" : "")
        } else if session.running {
            item.button?.title = " ∞"
            item.button?.toolTip = "Upkeep active · unlimited · double-Control to stop"
        } else {
            item.button?.title = ""
            item.button?.toolTip = "Upkeep is off" + (externalCount > 0 ? " · external caffeinate running (\(externalCount))" : "")
        }
    }
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let header = NSMenuItem(title: "Upkeep · \(session.mode.title)", action: nil, keyEquivalent: "")
        let card = MenuStatusCard(); card.update(mode: session.mode, deadline: session.deadline, seconds: seconds)
        header.view = card; menuCard = card; menu.addItem(header)
        if externalCount > 0 { menu.addItem(NSMenuItem(title: "\(externalCount) external session(s) · managed elsewhere", action: nil, keyEquivalent: "")) }
        menu.addItem(.separator())
        let section = NSMenuItem(title: "CHOOSE A MODE", action: nil, keyEquivalent: "")
        section.attributedTitle = NSAttributedString(string: section.title, attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: NSColor.secondaryLabelColor])
        menu.addItem(section)
        for (mode, action) in [(SessionMode.timed, #selector(startTimed(_:))), (.unlimited, #selector(startUnlimited(_:))), (.displayAwake, #selector(startDisplayAwake(_:)))] {
            let entry = add(mode.title, action)
            entry.state = session.mode == mode ? .on : .off
            entry.image = menuSymbol(mode == .timed ? "timer" : mode == .unlimited ? "infinity" : "display", color: mode.color)
            entry.attributedTitle = NSAttributedString(string: mode.title, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: session.mode == mode ? .semibold : .regular)])

        }
        if session.keepsDisplayAwake { menu.addItem(NSMenuItem(title: "Display kept awake until this session ends", action: nil, keyEquivalent: "")) }
        menu.addItem(.separator())
        if session.running, session.deadline != nil {
            add("Restart timer · \(durationNumber(Double(seconds) / 60)) minutes", #selector(restartTimer(_:))).image = menuSymbol("arrow.clockwise")
        }
        if session.running { add("Stop Upkeep", #selector(stopSession(_:))).image = menuSymbol("stop.circle.fill", color: .systemRed) }
        let hint = NSMenuItem(title: "⌃ twice · start / stop    ⌃⇧ · settings", action: nil, keyEquivalent: "")
        hint.attributedTitle = NSAttributedString(string: hint.title, attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        menu.addItem(hint)

        menu.addItem(.separator()); add("Settings…", #selector(showSettings(_:))).image = menuSymbol("gearshape")
        add("Quit Upkeep", #selector(quit(_:))).image = menuSymbol("power")
    }
    @discardableResult
    func add(_ title: String, _ action: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: ""); entry.target = self; menu.addItem(entry); return entry
    }
    func showSessionError(_ error: Error) {
        let alert = NSAlert(); alert.messageText = "Couldn’t change Upkeep session"; alert.informativeText = error.localizedDescription; alert.runModal()
    }
    func selectMode(_ mode: SessionMode, restart: Bool = false) {
        do { try session.select(mode, seconds: seconds, restart: restart) } catch { showSessionError(error) }
        scanExternal()
    }
    @objc func toggle(_ sender: Any?) { selectMode(session.running ? .off : .timed) }
    @objc func startTimed(_ sender: Any?) { selectMode(.timed) }
    @objc func startUnlimited(_ sender: Any?) { selectMode(.unlimited) }
    @objc func startDisplayAwake(_ sender: Any?) { selectMode(.displayAwake) }
    @objc func stopSession(_ sender: Any?) { selectMode(.off) }
    @objc func restartTimer(_ sender: Any?) {
        guard session.running, session.deadline != nil else { return }
        selectMode(session.mode, restart: true)
    }
    func label(_ text: String, _ frame: NSRect, size: CGFloat = 13) -> NSTextField {
        let view = NSTextField(labelWithString: text); view.frame = frame; view.font = .systemFont(ofSize: size); return view
    }
    @objc func showSettings(_ sender: Any?) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 450, height: 420), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Upkeep Settings"; w.isReleasedWhenClosed = false; w.delegate = self; w.center()
            let v = w.contentView!
            let image = NSImageView(frame: NSRect(x: 28, y: 335, width: 48, height: 48)); settingsIcon = image; v.addSubview(image)
            v.addSubview(label("Upkeep", NSRect(x: 92, y: 355, width: 300, height: 30), size: 26))
            stateLabel = label("A little more awake.", NSRect(x: 94, y: 330, width: 300, height: 22)); v.addSubview(stateLabel!)
            v.addSubview(label("Session duration", NSRect(x: 28, y: 284, width: 170, height: 22)))
            durationField = NSTextField(frame: NSRect(x: 220, y: 280, width: 82, height: 28)); v.addSubview(durationField)
            durationUnit = NSPopUpButton(frame: NSRect(x: 310, y: 280, width: 112, height: 28), pullsDown: false)
            durationUnit.addItems(withTitles: ["Minutes", "Hours"])
            durationUnit.target = self; durationUnit.action = #selector(changeDurationUnit(_:)); v.addSubview(durationUnit)
            v.addSubview(label("Global shortcut", NSRect(x: 28, y: 236, width: 170, height: 22)))
            shortcutLabel = label("⌃ twice: toggle timed / stop\n⌃ ⇧: Settings\n⌃ I: start unlimited\n⌃ D: timed + display awake", NSRect(x: 220, y: 174, width: 210, height: 84), size: 12); v.addSubview(shortcutLabel)
            enableButton = NSButton(title: "Enable for all apps…", target: self, action: #selector(enableShortcuts(_:)))
            enableButton!.frame = NSRect(x: 218, y: 126, width: 200, height: 30); enableButton!.bezelStyle = .rounded; v.addSubview(enableButton!)
            let hint = label("Tap Control twice to stop any session.", NSRect(x: 28, y: 90, width: 400, height: 25), size: 11); hint.textColor = .secondaryLabelColor; v.addSubview(hint)
            permissionLabel = label("", NSRect(x: 28, y: 70, width: 395, height: 20), size: 11); permissionLabel!.textColor = .secondaryLabelColor; v.addSubview(permissionLabel!)
            errorLabel = label("", NSRect(x: 28, y: 44, width: 395, height: 23), size: 11); errorLabel.textColor = .systemRed; v.addSubview(errorLabel)
            let save = NSButton(title: "Save duration", target: self, action: #selector(saveDuration(_:))); save.frame = NSRect(x: 290, y: 16, width: 132, height: 32); save.bezelStyle = .rounded; v.addSubview(save)
            startButton = NSButton(title: "Start Upkeep", target: self, action: #selector(toggle(_:))); startButton!.frame = NSRect(x: 28, y: 16, width: 132, height: 32); startButton!.bezelStyle = .rounded; v.addSubview(startButton!)
            window = w
        }
        displayedUnit = 0; durationUnit.selectItem(at: 0)
        durationField.stringValue = durationNumber(Double(seconds) / 60); errorLabel.stringValue = ""; refresh()
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
    @objc func saveDuration(_ sender: Any?) {
        guard let value = durationSeconds(durationField.stringValue, unit: durationUnit.indexOfSelectedItem) else {
            errorLabel.stringValue = "Enter a positive duration between 1 second and 1 year."; return
        }
        preferences.set(value, forKey: "duration")
        window?.close()
    }
    @objc func changeDurationUnit(_ sender: Any?) {
        let nextUnit = durationUnit.indexOfSelectedItem
        if let value = Double(durationField.stringValue), value.isFinite {
            let oldFactor = displayedUnit == 1 ? 3600.0 : 60.0
            let newFactor = nextUnit == 1 ? 3600.0 : 60.0
            durationField.stringValue = durationNumber(value * oldFactor / newFactor)
        }
        displayedUnit = nextUnit
    }
    @objc func quit(_ sender: Any?) { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate(); try? session.stop()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
    }
}

// Subprocess fixture for testing owner death without force-quitting the user's installed app.
if CommandLine.arguments.contains("--lifecycle-test-owner") {
    let mode = CommandLine.arguments.last!
    let fixture = Session()
    try fixture.start(seconds: mode == "unlimited" ? nil : 60, keepDisplayAwake: mode == "display")
    FileHandle.standardOutput.write(Data("\(fixture.process!.processIdentifier)\n".utf8))
    while true { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
} else if CommandLine.arguments.contains("--export-icon") {

    let image = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
        NSColor(calibratedRed: 0.12, green: 0.075, blue: 0.05, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), xRadius: 220, yRadius: 220).fill()
        coffeeIcon(mode: .timed, size: 640).draw(in: NSRect(x: 192, y: 192, width: 640, height: 640))
        return true
    }
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments.last!))
} else if CommandLine.arguments.contains("--self-test") {
    for (seconds, compact, detailed) in [
        (0, "1s", "1 second remaining"), (1, "1s", "1 second remaining"),
        (59, "59s", "59 seconds remaining"), (60, "1:00", "1m 0s remaining"),
        (3599, "59:59", "59m 59s remaining"), (3600, "1h 0m", "1h 0m 0s remaining"),
        (5420, "1h 30m", "1h 30m 20s remaining"), (86399, "23h 59m", "23h 59m 59s remaining"),
        (86400, "1d 0h", "1d 0h 0m remaining"), (94500, "1d 2h", "1d 2h 15m remaining"),
        (31_536_000, "365d 0h", "365d 0h 0m remaining")
    ] {
        precondition(remainingTime(seconds, compact: true) == compact)
        precondition(remainingTime(seconds, compact: false) == detailed)
        let card = MenuStatusCard()
        let deadline = Date().addingTimeInterval(Double(max(1, seconds)))
        card.update(mode: .displayAwake, deadline: deadline, seconds: seconds)
        precondition(card.countdown.stringValue == detailed && card.endLabel.stringValue.hasPrefix("Ends at "))
        let width = (detailed as NSString).size(withAttributes: [.font: card.countdown.font!]).width
        precondition(width <= card.countdown.frame.width - 6, "Countdown must fit the status card")
        card.update(mode: .unlimited, deadline: nil, seconds: seconds)
        precondition(card.endLabel.stringValue.isEmpty && card.countdown.stringValue == "∞  No time limit")
    }
    var endCalendar = Calendar(identifier: .gregorian)
    endCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let endNow = endCalendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 23))!
    let endToday = endNow.addingTimeInterval(1800), endTomorrow = endNow.addingTimeInterval(7200)
    let endFormatter = DateFormatter(); endFormatter.calendar = endCalendar; endFormatter.timeZone = endCalendar.timeZone; endFormatter.timeStyle = .short
    precondition(sessionEnd(endToday, now: endNow, calendar: endCalendar) == "Ends at " + endFormatter.string(from: endToday))
    endFormatter.dateStyle = .medium
    precondition(sessionEnd(endTomorrow, now: endNow, calendar: endCalendar) == "Ends at " + endFormatter.string(from: endTomorrow))
    print("PASS: countdown boundaries, active minimum, status-card text fit, infinite transition and end-date rollover")
    precondition(durationSeconds("60", unit: 0) == 3600)
    precondition(durationSeconds("1.5", unit: 1) == 5400)
    precondition(durationSeconds("0.5", unit: 0) == 30)
    for invalid in ["0", "-1", "nan", "inf", "garbage", "999999999999999"] {
        precondition(durationSeconds(invalid, unit: 0) == nil)
    }
    var detector = DoubleControlDetector()
    func controlTap(_ key: Int, _ start: Double, _ end: Double) -> Bool {
        precondition(!detector.flags(key: key, down: true, otherModifier: false, time: start))
        return detector.flags(key: key, down: false, otherModifier: false, time: end)
    }
    precondition(!controlTap(59, 0, 0.1))
    precondition(controlTap(59, 0.2, 0.3), "Double left Control must toggle")
    precondition(!controlTap(62, 1, 1.1))
    precondition(controlTap(62, 1.2, 1.3), "Double right Control must toggle")
    precondition(!controlTap(59, 2, 2.1))
    precondition(!controlTap(59, 3, 3.1), "Slow taps must not toggle")
    detector.reset()
    precondition(!controlTap(59, 4, 5), "Long hold must not count")
    precondition(!controlTap(59, 5.1, 5.2))
    detector.reset()
    precondition(!controlTap(59, 6, 6.1))
    detector.reset() // Any typed key or mouse click interrupts the sequence.
    precondition(!controlTap(59, 6.2, 6.3))
    precondition(!detector.flags(key: 59, down: true, otherModifier: true, time: 6.4))
    precondition(!detector.flags(key: 59, down: false, otherModifier: false, time: 6.5))
    precondition(!controlTap(59, 6.6, 6.7), "Control chords must not count")
    print("PASS: double Control, both sides, slow taps, holds, typing, and modifier chords")
    let ownerArguments = ["-w", String(ProcessInfo.processInfo.processIdentifier)]
    let session = Session()
    try session.start(seconds: 2)
    precondition(session.running && session.process?.arguments == ["-t", "2"] + ownerArguments)
    let until = Date().addingTimeInterval(4)
    while session.running && Date() < until { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
    precondition(!session.running, "Session failed to expire")
    try session.start(seconds: 30)
    let pid = session.process!.processIdentifier
    try session.stop()
    precondition(!session.running && kill(pid, 0) == -1, "Session failed to stop")
    try session.start(seconds: nil)
    precondition(session.running && session.deadline == nil && session.process?.arguments == ownerArguments)
    let unlimitedPID = session.process!.processIdentifier
    RunLoop.current.run(until: Date().addingTimeInterval(2.5))
    precondition(session.running, "Unlimited session must stay running")
    try session.stop()
    precondition(kill(unlimitedPID, 0) == -1)
    try session.start(seconds: 30)
    let timedPID = session.process!.processIdentifier
    try session.start(seconds: nil)
    precondition(kill(timedPID, 0) == -1 && session.running && session.deadline == nil)
    try session.stop()
    print("PASS: timed expiry, unlimited session, timed-to-unlimited replacement, restart, and cleanup")
    func ownedAssertions(_ pid: Int32) throws -> String {
        let command = Process(); let output = Pipe()
        command.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        command.arguments = ["-g", "assertions"]; command.standardOutput = output
        try command.run()
        let data = output.fileHandleForReading.readDataToEndOfFile(); command.waitUntilExit()
        precondition(command.terminationStatus == 0, "Could not inspect power assertions")
        return String(decoding: data, as: UTF8.self).split(separator: "\n").filter { $0.contains("pid \(pid)(") }.joined(separator: "\n")
    }
    func stubbornChild() throws -> Process {
        let child = Process(); let output = Pipe()
        child.executableURL = URL(fileURLWithPath: "/bin/sh")
        child.arguments = ["-c", "trap '' TERM; printf ready; while :; do :; done"]
        child.standardOutput = output
        try child.run()
        precondition(String(decoding: output.fileHandleForReading.availableData, as: UTF8.self) == "ready")
        return child
    }
    func freezeChild(_ pid: Int32) throws {

        precondition(kill(pid, SIGSTOP) == 0)
        let limit = ProcessInfo.processInfo.systemUptime + 1
        while ProcessInfo.processInfo.systemUptime < limit {
            let ps = Process(); let output = Pipe()
            ps.executableURL = URL(fileURLWithPath: "/bin/ps"); ps.arguments = ["-o", "state=", "-p", String(pid)]; ps.standardOutput = output
            try ps.run()
            let data = output.fileHandleForReading.readDataToEndOfFile(); ps.waitUntilExit()
            if String(decoding: data, as: UTF8.self).contains("T") { return }
            Thread.sleep(forTimeInterval: 0.005)
        }
        preconditionFailure("Fixture child did not become suspended")
    }
    func verifyDisplayAssertions(_ pid: Int32) throws {

        let limit = Date().addingTimeInterval(2)
        while Date() < limit {
            let assertions = try ownedAssertions(pid)
            if assertions.contains("PreventUserIdleDisplaySleep") && assertions.contains("PreventUserIdleSystemSleep") { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        preconditionFailure("Display session must create both display and idle system sleep assertions")
    }
    try session.start(seconds: 3, keepDisplayAwake: true)
    let displayPID = session.process!.processIdentifier
    precondition(session.keepsDisplayAwake && session.process?.arguments == ["-di", "-t", "3"] + ownerArguments)
    try verifyDisplayAssertions(displayPID)
    let displayExpiry = Date().addingTimeInterval(5)
    while session.running && Date() < displayExpiry { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    precondition(!session.running && !session.keepsDisplayAwake && session.deadline == nil)
    let expiredAssertions = try ownedAssertions(displayPID)
    precondition(expiredAssertions.isEmpty, "Expired display assertions must be released")
    print("PASS: actual macOS display + system assertions, timed display expiry and assertion cleanup")
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    let controller = AppDelegate()
    let testDomain = "local.upkeep.tests." + UUID().uuidString
    controller.preferences = UserDefaults(suiteName: testDomain)!
    defer { controller.preferences.removePersistentDomain(forName: testDomain) }
    controller.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    controller.preferences.register(defaults: ["duration": 7200])
    func drain() { RunLoop.current.run(until: Date().addingTimeInterval(0.15)) }
    func controlDouble(_ start: Double) {
        for (offset, down) in [(0.0, true), (0.1, false), (0.2, true), (0.3, false)] {
            controller.handleShortcutEvent(type: .flagsChanged, key: 59, flags: down ? .maskControl : [], time: start + offset)
        }
        drain()
    }
    controller.handleShortcutEvent(type: .keyDown, key: 34, flags: .maskControl, time: 10)
    drain()
    precondition(controller.session.running && controller.session.deadline == nil && controller.session.process?.arguments == ownerArguments)
    let firstPID = controller.session.process!.processIdentifier
    controller.handleShortcutEvent(type: .keyDown, key: 34, flags: .maskControl, time: 11, repeated: true)
    drain()
    precondition(controller.session.process!.processIdentifier == firstPID, "Repeat must not restart unlimited session")
    controlDouble(12)
    precondition(!controller.session.running, "Double Control must stop unlimited session")
    controlDouble(13)
    precondition(controller.session.running && controller.session.process?.arguments == ["-t", String(controller.seconds)] + ownerArguments)
    controlDouble(14)
    precondition(!controller.session.running, "Double Control must stop timed session")
    controller.handleShortcutEvent(type: .flagsChanged, key: 59, flags: .maskControl, time: 15)
    controller.handleShortcutEvent(type: .flagsChanged, key: 56, flags: [.maskControl, .maskShift], time: 15.1)
    drain()
    precondition(controller.window?.isVisible == true, "Control then Shift must open Settings")
    controller.window?.close()
    controller.handleShortcutEvent(type: .flagsChanged, key: 56, flags: [.maskControl, .maskShift], time: 15.2)
    drain()
    precondition(controller.window?.isVisible == false, "Held chord must not reopen Settings")
    controller.handleShortcutEvent(type: .flagsChanged, key: 59, flags: .maskShift, time: 15.3)
    controller.handleShortcutEvent(type: .flagsChanged, key: 62, flags: [.maskControl, .maskShift], time: 15.4)
    drain()
    precondition(controller.window?.isVisible == true, "Shift then right Control must open Settings")
    controller.window?.close()
    print("PASS: Control I unlimited, double Control start/stop, Control Shift Settings in either order, no repeated opening")
    let savedDuration = controller.preferences.object(forKey: "duration")
    defer {
        if let savedDuration { controller.preferences.set(savedDuration, forKey: "duration") }
        else { controller.preferences.removeObject(forKey: "duration") }
    }
    controller.showSettings(nil)
    controller.durationUnit.selectItem(at: 1)
    controller.changeDurationUnit(nil)
    controller.durationField.stringValue = "1.5"
    controller.saveDuration(nil)
    precondition(controller.seconds == 5400 && controller.window?.isVisible == false)
    controller.showSettings(nil)
    precondition(controller.durationUnit.indexOfSelectedItem == 0 && controller.durationField.stringValue == "90")
    controller.durationUnit.selectItem(at: 1); controller.changeDurationUnit(nil)
    precondition(controller.durationField.stringValue == "1.5", "Unit changes must preserve duration")
    controller.durationField.stringValue = "0"; controller.saveDuration(nil)
    precondition(controller.window?.isVisible == true && controller.seconds == 5400)
    controller.window?.close()
    print("PASS: minutes default, fractional hours, unit conversion, save closes Settings, invalid input stays open")
    controller.handleShortcutEvent(type: .keyDown, key: 2, flags: [.maskControl, .maskShift], time: 20)
    controller.handleShortcutEvent(type: .keyDown, key: 2, flags: [], time: 20.1)
    controller.handleShortcutEvent(type: .keyDown, key: 2, flags: [.maskControl, .maskAlternate], time: 20.2)
    controller.handleShortcutEvent(type: .keyDown, key: 2, flags: [.maskControl, .maskCommand], time: 20.3)
    drain()
    precondition(!controller.session.running, "Only unmodified Control D may start display mode")
    controller.handleShortcutEvent(type: .keyDown, key: 2, flags: .maskControl, time: 21)
    drain()
    precondition(controller.session.keepsDisplayAwake && controller.session.process?.arguments == ["-di", "-t", "5400"] + ownerArguments, "Control D must use the saved duration")
    let shortcutDisplayPID = controller.session.process!.processIdentifier
    try verifyDisplayAssertions(shortcutDisplayPID)
    controller.refresh(); controller.menuWillOpen(controller.menu)
    precondition(controller.item.button?.toolTip?.contains("display awake") == true)
    precondition(controller.menu.items.contains { $0.title == "Display kept awake until this session ends" })
    controller.handleShortcutEvent(type: .keyDown, key: 2, flags: .maskControl, time: 21.1, repeated: true)
    drain()
    precondition(controller.session.process?.processIdentifier == shortcutDisplayPID, "Held Control D must not restart the timer")
    controlDouble(22)
    precondition(!controller.session.running && !controller.session.keepsDisplayAwake && kill(shortcutDisplayPID, 0) == -1)
    let stoppedAssertions = try ownedAssertions(shortcutDisplayPID)
    precondition(stoppedAssertions.isEmpty, "Double Control must release display assertions")
    controlDouble(23)
    let plainPID = controller.session.process!.processIdentifier
    precondition(!controller.session.keepsDisplayAwake && controller.session.process?.arguments == ["-t", "5400"] + ownerArguments)
    controller.handleShortcutEvent(type: .keyDown, key: 2, flags: .maskControl, time: 24)
    drain()
    precondition(kill(plainPID, 0) == -1 && controller.session.keepsDisplayAwake, "Control D must replace the timed session")
    let replacedDisplayPID = controller.session.process!.processIdentifier
    controller.handleShortcutEvent(type: .keyDown, key: 34, flags: .maskControl, time: 25)
    drain()
    precondition(kill(replacedDisplayPID, 0) == -1 && !controller.session.keepsDisplayAwake && controller.session.deadline == nil)
    let replacedAssertions = try ownedAssertions(replacedDisplayPID)
    precondition(replacedAssertions.isEmpty, "Unlimited mode must release the old display assertion")
    let replacedUnlimitedPID = controller.session.process!.processIdentifier
    controller.handleShortcutEvent(type: .keyDown, key: 2, flags: .maskControl, time: 26)
    drain()
    precondition(kill(replacedUnlimitedPID, 0) == -1 && controller.session.keepsDisplayAwake && controller.session.deadline != nil)
    try verifyDisplayAssertions(controller.session.process!.processIdentifier)
    controller.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    precondition(!controller.session.running && !controller.session.keepsDisplayAwake)
    print("PASS: Control D saved duration, repeat/chord filtering, indicators, double Control stop, mode replacement and quit cleanup")
    // Activate the same NSMenuItems used by mouse selection for every mode pair.
    func menuAction(_ title: String) {
        controller.menuWillOpen(controller.menu)
        guard let entry = controller.menu.items.first(where: { $0.title == title }), let action = entry.action else { preconditionFailure("Missing menu action: \(title)") }
        precondition(application.sendAction(action, to: entry.target, from: entry))
        controller.refresh()
    }
    let modes: [SessionMode] = [.timed, .unlimited, .displayAwake]
    for source in [SessionMode.off] + modes {
        for target in modes {
            try controller.session.stop()
            if source != .off { try controller.session.start(seconds: source == .unlimited ? nil : 5, keepDisplayAwake: source == .displayAwake) }
            let previousPID = controller.session.process?.processIdentifier
            let previousDeadline = controller.session.deadline
            menuAction(target.title)
            precondition(controller.session.mode == target, "Menu selected the wrong mode")
            if source == target {
                precondition(controller.session.process?.processIdentifier == previousPID && controller.session.deadline == previousDeadline, "Selecting the current mode must be a no-op")

            } else if target != .unlimited {
                precondition(abs(controller.session.deadline!.timeIntervalSinceNow - Double(controller.seconds)) < 1, "A fresh timer must use the saved duration")
            } else { precondition(controller.session.deadline == nil) }
            if let previousPID, source != target { precondition(kill(previousPID, 0) == -1, "Replaced child survived") }
            controller.menuWillOpen(controller.menu)
            let checked = controller.menu.items.filter { $0.state == .on }
            precondition(checked.count == 1 && checked[0].title == target.title)
            precondition(modes.allSatisfy { mode in controller.menu.items.contains { $0.title == mode.title && $0.action != nil } })
            precondition(controller.menu.items.contains { $0.title == "Stop Upkeep" })
            precondition(controller.menu.items.contains { $0.title.hasPrefix("Restart timer") } == (target != .unlimited))
            precondition(controller.stateLabel?.textColor == target.color && controller.item.button?.image?.isTemplate == false)
            if target == .unlimited { precondition(controller.item.button?.title == " ∞") }
            if target == .displayAwake { try verifyDisplayAssertions(controller.session.process!.processIdentifier) }
            menuAction("Stop Upkeep")
            precondition(controller.session.mode == .off && controller.item.button?.image?.isTemplate == true)
        }
    }
    controller.menuWillOpen(controller.menu)
    precondition(!controller.menu.items.contains { $0.state == .on || $0.title == "Stop Upkeep" || $0.title.hasPrefix("Restart timer") })
    try controller.session.start(seconds: 5, keepDisplayAwake: true)
    let restartPID = controller.session.process!.processIdentifier
    menuAction("Restart timer · 90 minutes")
    precondition(controller.session.mode == .displayAwake && kill(restartPID, 0) == -1)
    precondition(abs(controller.session.deadline!.timeIntervalSinceNow - 5400) < 1)
    let shortcutDeadline = controller.session.deadline
    let shortcutPID = controller.session.process!.processIdentifier
    controller.handleShortcutEvent(type: .keyDown, key: 2, flags: .maskControl, time: 30)
    drain()
    precondition(controller.session.deadline == shortcutDeadline && controller.session.process?.processIdentifier == shortcutPID, "Control D on the same mode must not reset time")
    controller.startTimed(nil)
    precondition(controller.session.deadline != shortcutDeadline && !controller.session.keepsDisplayAwake)
    precondition(abs(controller.session.deadline!.timeIntervalSinceNow - 5400) < 1)
    let ordinaryTimedDeadline = controller.session.deadline
    controller.handleShortcutEvent(type: .keyDown, key: 2, flags: .maskControl, time: 31)
    drain()
    precondition(controller.session.deadline != ordinaryTimedDeadline && controller.session.keepsDisplayAwake, "Control D must refresh the timed deadline")
    precondition(abs(controller.session.deadline!.timeIntervalSinceNow - 5400) < 1)
    try controller.session.stop()
    // A short old timer must not expire the replacement after a mode switch.
    controller.preferences.set(2, forKey: "duration")
    try controller.session.start(seconds: 1)
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    let oldDeadline = controller.session.deadline!
    menuAction("Timed + display")
    let refreshedDeadline = controller.session.deadline!
    precondition(refreshedDeadline > oldDeadline && abs(refreshedDeadline.timeIntervalSinceNow - 2) < 0.3)
    RunLoop.current.run(until: Date().addingTimeInterval(0.7))
    precondition(controller.session.running && controller.session.deadline == refreshedDeadline, "The old expiry timer must not stop a refreshed session")
    let expiryLimit = Date().addingTimeInterval(3)
    while controller.session.running && Date() < expiryLimit { drain() }
    precondition(!controller.session.running, "The refreshed timer must expire normally")
    // A changed saved duration applies on the next timed-mode switch, not mid-session.
    try controller.session.start(seconds: 5, keepDisplayAwake: true)
    controller.preferences.set(3, forKey: "duration")
    menuAction("Timed")
    precondition(controller.session.process?.arguments == ["-t", "3"] + ownerArguments)
    precondition(abs(controller.session.deadline!.timeIntervalSinceNow - 3) < 0.3)
    try controller.session.stop()
    controller.preferences.set(5400, forKey: "duration")
    let expiringChild = try stubbornChild()
    controller.session.process = expiringChild
    controller.session.deadline = Date().addingTimeInterval(0.02)
    controller.startDisplayAwake(nil)
    precondition(controller.session.mode == .displayAwake && !expiringChild.isRunning, "A switch must start a fresh timer after the old child is stopped")
    precondition(abs(controller.session.deadline!.timeIntervalSinceNow - 5400) < 1)
    precondition(expiringChild.terminationReason == .uncaughtSignal && expiringChild.terminationStatus == SIGKILL, "Stop must escalate when SIGTERM is ignored")
    try controller.session.stop()
    print("PASS: all 12 menu mode selections, same-mode no-op, full-duration timed switches in both directions, Control D refresh, saved-duration changes, old timer cancellation and expiry cleanup")
    // Exercise the actual OS owner watcher, including death immediately after spawn.

    for signal in [SIGTERM, SIGKILL] {
        for mode in ["timed", "unlimited", "display"] {
            for attempt in 0..<3 {
                let owner = Process(); let output = Pipe()
                owner.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
                owner.arguments = ["--lifecycle-test-owner", mode]; owner.standardOutput = output
                try owner.run()
                let data = output.fileHandleForReading.availableData
                guard let childPID = Int32(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)) else { preconditionFailure("Missing fixture PID") }
                if attempt == 0 { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
                kill(owner.processIdentifier, signal); owner.waitUntilExit()
                let limit = ProcessInfo.processInfo.systemUptime + 4
                while kill(childPID, 0) == 0 && ProcessInfo.processInfo.systemUptime < limit { Thread.sleep(forTimeInterval: 0.01) }
                precondition(kill(childPID, 0) == -1, "Owner death left a caffeinate process behind")
                let assertions = try ownedAssertions(childPID)
                precondition(assertions.isEmpty, "Owner death left sleep prevention behind")
            }
        }
    }
    let unrelated = Process()
    unrelated.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate"); unrelated.arguments = ["-t", "30"]
    try unrelated.run()
    try session.start(seconds: nil)
    let frozenPID = session.process!.processIdentifier
    try freezeChild(frozenPID)
    let stopStart = ProcessInfo.processInfo.systemUptime
    try session.stop()
    precondition(ProcessInfo.processInfo.systemUptime - stopStart < 1.5, "Stopping a frozen child exceeded the bound")
    precondition(kill(frozenPID, 0) == -1 && unrelated.isRunning, "Stop must clean up only its own child")
    unrelated.terminate(); unrelated.waitUntilExit()
    for index in 0..<30 {
        try session.start(seconds: index % 2 == 0 ? nil : 30, keepDisplayAwake: index % 3 == 0)
        let currentPID = session.process!.processIdentifier
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        precondition(session.process?.processIdentifier == currentPID && session.running, "An old termination callback cleared the new session")
    }
    let finalPID = session.process!.processIdentifier
    try session.stop()
    precondition(kill(finalPID, 0) == -1)
    print("PASS: all modes clean up after SIGTERM/SIGKILL and immediate owner death; frozen-child stop bounded; external process untouched; 30 rapid replacements")

} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    // LaunchServices handles normal launches; direct launches also avoid duplicate status items.
    if NSRunningApplication.runningApplications(withBundleIdentifier: "local.brew.menubar").filter({ $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }).isEmpty {
        let delegate = AppDelegate(); app.delegate = delegate; app.run()
    }
}
