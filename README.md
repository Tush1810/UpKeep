# Upkeep ☕

A native macOS menu bar app that keeps your Mac awake with `caffeinate`.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Double-tap Control (⌃) | Start a timed session when off; stop either session type when active |
| Control + Shift | Open Settings |
| Control + I | Start unlimited caffeination, or convert a timed session to unlimited |

An unlimited session runs `caffeinate` without a timeout and shows **∞**. Double-Control, Stop Upkeep, or Quit ends it. Pressing Control+I again leaves the current unlimited session running.

Double-Control accepts two quick press-and-release taps, with at most 450 ms between taps. Either Control key works. Another key, another modifier, a mouse click, or a long hold cancels the sequence. The listener is passive; shortcuts may also retain the focused app’s normal behavior.

## Duration and indicators

Settings opens in **Minutes** by default and offers **Hours** in a dropdown. Switching units converts the displayed value. Fractional values such as **1.5 hours** work. **Save duration** saves and closes Settings; invalid input keeps the window open.

The initial duration is **120 minutes**. Settings persist between launches. Duration changes apply to the next timed session.

- Outlined coffee cup: off.
- Amber cup and countdown: timed session active.
- Amber cup and **∞**: unlimited session active.

External caffeinate sessions appear separately in the menu and tooltip. Upkeep stops only its own process. It prevents idle system sleep; display sleep and lid-close behavior follow macOS settings.

Hold Command and drag the menu bar icon to reposition it.

## Build and install

Requires macOS 13 or later and Apple Command Line Tools. No third-party dependencies are needed. The build targets the Mac’s native architecture.

```sh
git clone https://github.com/Tush1810/UpKeep.git
cd UpKeep
git switch dev
./build.sh
./Upkeep.app/Contents/MacOS/Upkeep --self-test
```

The build creates `Upkeep.app` and `Upkeep.zip` in the repository root. Move `Upkeep.app` to Applications and open it.

To start at login, add it under System Settings → General → Login Items.

## Input Monitoring

Global shortcuts require System Settings → Privacy & Security → Input Monitoring → Upkeep. **Enable for all apps…** in Settings opens the permission setup. Relaunch if macOS requests it. The app displays **Enabled for all apps** only when its global listener is available.

Local ad-hoc signing changes the app’s identity after a rebuild. If a permission switch remains on but the updated app cannot listen, remove the old Upkeep permission entry, add the installed app again, and relaunch. You can reset only this app’s stale approval with:

```sh
tccutil reset ListenEvent local.brew.menubar
```

The legacy bundle identifier is retained to preserve existing settings.

## Verification

`--self-test` checks duration conversion and validation, saving and closing Settings, timed expiry, unlimited sessions, timed-to-unlimited conversion, process cleanup, double-Control detection, and shortcut action routing. Tests briefly open a Settings window and restore the saved duration afterward.

Modifier-only global gestures also need a physical keyboard check; synthetic app-targeted input may not reach macOS’s global event tap.

The default development branch is **dev**.
