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

func coffeeIcon(active: Bool, size: CGFloat = 22) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let scale = size / 22
        let transform = NSAffineTransform()
        transform.scale(by: scale)
        transform.concat()
        (active ? NSColor.systemOrange : NSColor.labelColor).set()
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

final class Session {
    var process: Process?
    var deadline: Date?
    var changed: (() -> Void)?
    var running: Bool { process?.isRunning == true }
    func start(seconds: Int?) throws {
        if running { stop() }
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        child.arguments = seconds.map { ["-t", String($0)] } ?? []
        child.terminationHandler = { [weak self, weak child] _ in
            DispatchQueue.main.async {
                guard let self, self.process === child else { return }
                self.process = nil; self.deadline = nil; self.changed?()
            }
        }
        try child.run()
        process = child; deadline = seconds.map { Date().addingTimeInterval(Double($0)) }; changed?()
    }
    func stop() {
        let child = process
        process = nil; deadline = nil
        if child?.isRunning == true { child?.terminate(); child?.waitUntilExit() }
        changed?()
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
    var item: NSStatusItem!
    let menu = NSMenu()
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
    var seconds: Int { UserDefaults.standard.integer(forKey: "duration") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["duration": 7200])
        if seconds < 1 || seconds > 31_536_000 { UserDefaults.standard.set(7200, forKey: "duration") }
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
        let active = session.running
        stateLabel?.stringValue = active ? (session.deadline == nil ? "Upkeep active · unlimited" : "Upkeep session active") : "Upkeep is off"
        stateLabel?.textColor = active ? .systemOrange : .secondaryLabelColor
        startButton?.title = session.running ? "Stop Upkeep" : "Start Upkeep"
        enableButton?.title = eventTap == nil ? "Enable for all apps…" : "Enabled for all apps ✓"
        enableButton?.isEnabled = eventTap == nil
        permissionLabel?.stringValue = eventTap == nil ? "Input Monitoring needed for other apps." : "Shortcuts are ready in every app."
        item.button?.image = coffeeIcon(active: active)
        settingsIcon?.image = coffeeIcon(active: active, size: 48)
        if session.running, let deadline = session.deadline {
            let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
            item.button?.title = String(format: " %d:%02d", remaining / 60, remaining % 60)
            item.button?.toolTip = "Upkeep active · \(remaining) seconds remaining" + (externalCount > 0 ? " · external caffeinate also running" : "")
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
        let heading = NSMenuItem(title: session.running ? "☕ Upkeep is keeping you awake" : "☕ Upkeep is off", action: nil, keyEquivalent: "")
        menu.addItem(heading)
        if externalCount > 0 { menu.addItem(NSMenuItem(title: "\(externalCount) external session(s) · managed elsewhere", action: nil, keyEquivalent: "")) }
        menu.addItem(.separator())
        add(session.running ? "Stop Upkeep session" : "Start Upkeep · \(durationNumber(Double(seconds) / 60)) minutes", #selector(toggle(_:)))
        add("Start unlimited · ⌃I", #selector(startUnlimited(_:)))
        menu.addItem(NSMenuItem(title: "Toggle: double-tap ⌃ Control", action: nil, keyEquivalent: ""))
        menu.addItem(.separator()); add("Settings…", #selector(showSettings(_:)))
        add("Quit Upkeep", #selector(quit(_:)))
    }
    func add(_ title: String, _ action: Selector) { let entry = NSMenuItem(title: title, action: action, keyEquivalent: ""); entry.target = self; menu.addItem(entry) }
    @objc func toggle(_ sender: Any?) {
        if session.running { session.stop() } else {
            do { try session.start(seconds: seconds) } catch {
                let alert = NSAlert(); alert.messageText = "Couldn’t start caffeinate"; alert.informativeText = error.localizedDescription; alert.runModal()
            }
        }
        scanExternal()
    }
    @objc func startUnlimited(_ sender: Any?) {
        guard !session.running || session.deadline != nil else { return }
        do { try session.start(seconds: nil) } catch {
            let alert = NSAlert(); alert.messageText = "Couldn’t start caffeinate"; alert.informativeText = error.localizedDescription; alert.runModal()
        }
        scanExternal()
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
            shortcutLabel = label("⌃ twice: toggle timed / stop\n⌃ ⇧: Settings\n⌃ I: start unlimited", NSRect(x: 220, y: 180, width: 210, height: 78), size: 12); v.addSubview(shortcutLabel)
            enableButton = NSButton(title: "Enable for all apps…", target: self, action: #selector(enableShortcuts(_:)))
            enableButton!.frame = NSRect(x: 218, y: 126, width: 200, height: 30); enableButton!.bezelStyle = .rounded; v.addSubview(enableButton!)
            let hint = label("Tap Control twice to stop either session type.", NSRect(x: 28, y: 90, width: 400, height: 25), size: 11); hint.textColor = .secondaryLabelColor; v.addSubview(hint)
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
        UserDefaults.standard.set(value, forKey: "duration")
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
        timer?.invalidate(); session.stop()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
    }
}

if CommandLine.arguments.contains("--export-icon") {
    let image = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
        NSColor(calibratedRed: 0.12, green: 0.075, blue: 0.05, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), xRadius: 220, yRadius: 220).fill()
        coffeeIcon(active: true, size: 640).draw(in: NSRect(x: 192, y: 192, width: 640, height: 640))
        return true
    }
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments.last!))
} else if CommandLine.arguments.contains("--self-test") {
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
    let session = Session()
    try session.start(seconds: 2)
    precondition(session.running && session.process?.arguments == ["-t", "2"])
    let until = Date().addingTimeInterval(4)
    while session.running && Date() < until { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
    precondition(!session.running, "Session failed to expire")
    try session.start(seconds: 30)
    let pid = session.process!.processIdentifier
    session.stop()
    precondition(!session.running && kill(pid, 0) == -1, "Session failed to stop")
    try session.start(seconds: nil)
    precondition(session.running && session.deadline == nil && session.process?.arguments == [])
    let unlimitedPID = session.process!.processIdentifier
    RunLoop.current.run(until: Date().addingTimeInterval(2.5))
    precondition(session.running, "Unlimited session must stay running")
    session.stop()
    precondition(kill(unlimitedPID, 0) == -1)
    try session.start(seconds: 30)
    let timedPID = session.process!.processIdentifier
    try session.start(seconds: nil)
    precondition(kill(timedPID, 0) == -1 && session.running && session.deadline == nil)
    session.stop()
    print("PASS: timed expiry, unlimited session, timed-to-unlimited replacement, restart, and cleanup")
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    let controller = AppDelegate()
    controller.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    UserDefaults.standard.register(defaults: ["duration": 7200])
    func drain() { RunLoop.current.run(until: Date().addingTimeInterval(0.15)) }
    func controlDouble(_ start: Double) {
        for (offset, down) in [(0.0, true), (0.1, false), (0.2, true), (0.3, false)] {
            controller.handleShortcutEvent(type: .flagsChanged, key: 59, flags: down ? .maskControl : [], time: start + offset)
        }
        drain()
    }
    controller.handleShortcutEvent(type: .keyDown, key: 34, flags: .maskControl, time: 10)
    drain()
    precondition(controller.session.running && controller.session.deadline == nil && controller.session.process?.arguments == [])
    let firstPID = controller.session.process!.processIdentifier
    controller.handleShortcutEvent(type: .keyDown, key: 34, flags: .maskControl, time: 11, repeated: true)
    drain()
    precondition(controller.session.process!.processIdentifier == firstPID, "Repeat must not restart unlimited session")
    controlDouble(12)
    precondition(!controller.session.running, "Double Control must stop unlimited session")
    controlDouble(13)
    precondition(controller.session.running && controller.session.process?.arguments == ["-t", String(controller.seconds)])
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
    let savedDuration = UserDefaults.standard.object(forKey: "duration")
    defer {
        if let savedDuration { UserDefaults.standard.set(savedDuration, forKey: "duration") }
        else { UserDefaults.standard.removeObject(forKey: "duration") }
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
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    // LaunchServices handles normal launches; direct launches also avoid duplicate status items.
    if NSRunningApplication.runningApplications(withBundleIdentifier: "local.brew.menubar").filter({ $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }).isEmpty {
        let delegate = AppDelegate(); app.delegate = delegate; app.run()
    }
}
