# Upkeep ☕

Keep your Mac awake while you work, download, or wait for something to finish.

Upkeep is a small native macOS menu bar app powered by Apple's `caffeinate` command. Start a timed session with a double-tap of Control, or keep your Mac awake indefinitely with Control + I. A coffee cup in the menu bar shows whether Upkeep is active.

## Features

- Timed sessions with a default duration of **120 minutes** (7,200 seconds).
- Unlimited sessions that run until you stop them.
- Duration settings in **minutes or hours**, including fractional values.
- Global keyboard shortcuts for starting, stopping, and opening Settings.
- A timed **display-awake** mode to keep the screen from going black through idle display sleep.
- A color for each active mode, with a countdown or **∞**; an outlined cup while off.
- Native Swift and AppKit, with no third-party dependencies.

## Install

### Requirements

- A Mac running **macOS 13 Ventura or later**.
- Apple's **Command Line Tools for Xcode**, or a full Xcode installation.

Build on the Mac where you plan to use Upkeep. The build creates an app for that Mac's architecture: Apple Silicon or Intel, rather than a universal binary. Homebrew is not required.

### 1. Install Apple's developer tools

Open **Terminal** and run:

```sh
xcode-select --install
```

Complete the installer before continuing. If the tools are already installed, skip this step. You can confirm the Swift compiler is available with:

```sh
xcrun swiftc --version
```

### 2. Download and build Upkeep

In Terminal, run:

```sh
git clone --branch dev https://github.com/Tush1810/UpKeep.git
cd UpKeep
./build.sh
```

The script compiles the app, generates its coffee icon, and signs it locally. It creates **Upkeep.app** and **Upkeep.zip** in the repository folder. The zip contains the same app for sharing or archiving; it is built for your Mac's architecture.

### 3. Move the app to Applications

From the same Terminal window, copy the app into Applications and open it:

```sh
ditto --norsrc --noextattr --noqtn Upkeep.app /Applications/Upkeep.app
open /Applications/Upkeep.app
```

The copy command leaves behind filesystem metadata that can interfere with local code signing in synced folders. If your account cannot write to Applications, use your personal Applications folder instead:

```sh
mkdir -p "$HOME/Applications"
ditto --norsrc --noextattr --noqtn Upkeep.app "$HOME/Applications/Upkeep.app"
open "$HOME/Applications/Upkeep.app"
```

Look for the coffee cup in the menu bar at the top of your screen. Upkeep runs there without a Dock icon.

### 4. Enable global shortcuts

1. Click the coffee cup and choose **Settings…**.
2. Click **Enable for all apps…**.
3. In **System Settings → Privacy & Security → Input Monitoring**, enable **Upkeep**. Authenticate if macOS asks.
4. If Upkeep is missing from the list, click **+** and select the copy you installed in Applications (or your personal Applications folder).
5. Quit and reopen Upkeep if macOS requests it.

Settings shows **Enabled for all apps ✓** when the global keyboard listener is available. You can also start and stop sessions from the coffee cup menu.

### Optional: start at login

Add **Upkeep.app** under **System Settings → General → Login Items → Open at Login**. On newer macOS versions, this page may be named **Login Items & Extensions**.

## Use Upkeep

| Shortcut | Action |
| --- | --- |
| Double-tap **Control (⌃)** | Start a timed session when off; stop the current timed or unlimited session when active |
| **Control + Shift (⌃ ⇧)** | Open Settings |
| **Control + I (⌃ I)** | Start an unlimited session, or change the current timed session to unlimited |
| **Control + D (⌃ D)** | Switch to timed + display with a fresh saved-duration timer; no reset when already active |

Double-tap Control with two quick press-and-release taps, no more than **450 ms** apart. Either Control key works. A long hold, another key or modifier, or a mouse click cancels the double-tap sequence. For Settings, press Control and Shift together; either order works.

The shortcuts are currently fixed. The listener is passive, so a shortcut can also trigger the focused app's usual action.

Pressing Control + I during an unlimited session leaves it running. Double-tap Control, choose **Stop Upkeep** from the menu, or quit Upkeep to stop it.

**Control + D** selects timed + display mode. When already in that mode, it leaves the process and timer unchanged. From ordinary timed, off, or infinite mode it starts a fresh timer using the full saved duration. The cup turns cyan with a countdown, and the menu, tooltip, and Settings identify **display awake** mode. Double-Control stops it; its sleep prevention also ends when the timer expires or you quit Upkeep. Control + I selects infinite mode and releases display sleep prevention.

### Switch modes from the coffee cup

The menu always offers **Timed**, **Infinite**, and **Timed + display**. A checkmark identifies the active mode. A rounded status card at the top shows the coffee cup, active mode, a live countdown or **No time limit**, and whether the display stays awake. Each mode has a colored symbol; the checked mode also uses a heavier label. Session controls and Settings are separated into clear groups, with a compact shortcut reminder. The menu follows the Mac’s light or dark appearance and keeps native mouse and keyboard navigation.

| Selection | Behavior |
| --- | --- |
| Select the current mode | Keep the current process and timer unchanged |
| Timed ↔ Timed + display | Start a fresh timer using the full saved duration; change display sleep prevention |
| Either timed mode → Infinite | Remove the deadline and release display sleep prevention |
| Infinite → either timed mode | Start a fresh timer using the saved duration |
| Any mode while off | Start that mode; timed modes use the saved duration |
| Restart timer | Start the current timed mode again using the full saved duration |
| Stop Upkeep | End the current session and return to off |

**Restart timer** appears only during timed modes; **Stop Upkeep** appears whenever active. **Settings…** and **Quit Upkeep** remain available. Selecting a different mode replaces the owned caffeinate process; selecting the same mode does not. Countdown and mode colors remain visible. Every switch to a different timed mode resets the countdown using the latest saved duration. For example, with a one-hour setting, switching after 30 minutes starts a new full hour; switching back later starts another full hour. Clicking the mode already active leaves its current countdown unchanged.

While the dropdown is open, shortcut changes and timer expiry update its checkmark, mode label, and available session controls immediately. Stop appears only while active; Restart timer appears only during timed modes.

### Change the duration

Open Settings from the menu or with **Control + Shift**. Enter a positive number and choose **Minutes** or **Hours** from the dropdown:

| Setting | Timed session length |
| --- | --- |
| 30 Minutes | Half an hour |
| 120 Minutes | Two hours (the initial default) |
| 1.5 Hours | Ninety minutes |

Settings opens in **Minutes** by default. Changing the unit converts the displayed value, preserving the duration. Click **Save duration** to save and close the window. Invalid input leaves the window open so you can correct it.

Your duration is remembered between launches and applies to the **next timed start, timed-mode switch, or explicit restart**. Saving a duration does not change a session already running. Unlimited sessions have no timeout.

### Read the menu bar indicator

| Indicator | State |
| --- | --- |
| Outlined coffee cup | Upkeep is off |
| Amber cup (`#F5A623`) and countdown | A timed session is running |
| Violet cup (`#A78BFA`) and **∞** | An unlimited session is running |
| Cyan cup (`#22D3EE`) and countdown | A timed session keeps the display awake |

The Settings coffee cup and active status text use the same mode color. Countdowns, **∞**, tooltips, and existing status labels remain available alongside the colors.

The menu bar keeps the countdown compact; the dropdown shows more detail:

| Time remaining | Menu bar | Dropdown |
| --- | --- | --- |
| Under 1 minute | `45s` | `45 seconds remaining` |
| 1–59 minutes | `12:34` | `12m 34s remaining` |
| 1–under 24 hours | `1h 30m` | `1h 30m 20s remaining` |
| 24 hours or more | `1d 2h` | `1d 2h 15m remaining` |

At exactly one hour the menu bar shows `1h 0m`; at exactly 24 hours it shows `1d 0h`. An active countdown shows at least `1s` before returning to off. The dropdown and tooltip also show **Ends at**, using your local time and including the date when the session ends on another day. Infinite sessions continue to show **∞** without an end time.

Hold **Command** and drag the icon to reposition it in the menu bar.

Standard timed and unlimited sessions prevent **idle system sleep** and let the display sleep according to macOS settings. Control + D additionally prevents **idle display sleep**, using `caffeinate -di -t <seconds>`. Standard timed sessions use `caffeinate -t <seconds>`; unlimited sessions use `caffeinate`. These modes do not override lid-close behavior or explicit sleep/lock actions. Each command also includes `-w <Upkeep PID>` so it ends when its owning app exits, including a force-quit. Other caffeinate processes appear separately in the menu and tooltip; Upkeep stops only its own process.

## Process cleanup

Every session watches its owning Upkeep process using caffeinate's `-w` option. Timed modes end on timeout or owner exit; unlimited mode ends on stop or owner exit. Normal stopping and quitting also terminate the owned child explicitly.

Session changes are serialized on the main thread. Switching stops the old process before starting its replacement, and delayed exit callbacks check process identity before changing state. Stopping allows 250 ms for normal termination, then uses a targeted forced kill with a further 750 ms bound. If the previous child still cannot be stopped, Upkeep reports an error and does not start another process. Other applications' caffeinate processes are left alone.

An app timer enforces each timed session’s deadline, while caffeinate also has its own timeout as a fallback. The owner watcher depends on macOS scheduling caffeinate; it is not an instantaneous cleanup guarantee if the child itself is externally suspended or the OS is stalled.

## Update

Quit Upkeep from its menu first. In your cloned repository, run:

```sh
git switch dev
git pull --ff-only
./build.sh
ditto --norsrc --noextattr --noqtn Upkeep.app /Applications/Upkeep.app
open /Applications/Upkeep.app
```

These commands replace the installed app and reopen it. If you used your personal Applications folder, use that destination for the last two commands instead. Saved settings are retained. You may need to refresh Input Monitoring permission after rebuilding, as described below.

## Troubleshooting

### Shortcuts do not work outside Settings

Check that **Upkeep** is enabled in **Input Monitoring**, then quit and reopen it. Use the coffee cup menu while setting up permission.

Locally signed rebuilds can change the app's signing identity. macOS may show an enabled permission switch while still holding approval for an older build. Remove the old Upkeep entry from Input Monitoring, add the installed copy again with **+**, enable it, and relaunch.

If the approval is still stale, quit Upkeep and reset only its Input Monitoring permission:

```sh
tccutil reset ListenEvent local.brew.menubar
```

Then reopen Upkeep and grant permission again. `local.brew.menubar` is the retained bundle identifier from the app's original name; it also preserves existing settings.

### The build cannot find Swift

Finish installing Apple's Command Line Tools and confirm `xcrun swiftc --version` works before rerunning `./build.sh`.

### The app is running but there is no Dock icon

This is expected: Upkeep lives in the menu bar. If the coffee cup is hidden, check your menu bar manager or available menu bar space.

## Development and verification

The default branch is **dev**. After building, run the built-in checks:

```sh
./Upkeep.app/Contents/MacOS/Upkeep --self-test
```

These checks cover duration conversion and validation, saving and closing Settings, timed expiry, unlimited sessions, session transitions, process cleanup, double-Control detection, and shortcut action routing. Display-awake checks inspect the actual macOS display and system power assertions, verify their release on timeout and stop, and check mode transitions, key-repeat filtering, and use of the saved duration. Menu checks exercise every source/target mode pair through the actual menu actions, checked states, same-mode no-ops, full-duration resets in both timed-switch directions, saved-duration changes, explicit restart, old timer cancellation, and near-expiry switching. Lifecycle checks also kill isolated owner fixtures in every mode, test immediate owner death, stop a frozen child, check rapid replacements and stale callbacks, and verify unrelated caffeinate processes are untouched. Tests briefly open a Settings window and use an isolated preferences domain, leaving your saved duration unchanged.

For an end-to-end global shortcut check, enable Input Monitoring and focus another app:

1. Double-tap Control and confirm an amber countdown appears.
2. Double-tap Control again and confirm the cup returns to its off state.
3. Press Control + I and confirm **∞** appears; double-tap Control to stop it.
4. Press Control + Shift and confirm Settings opens.
5. Save a new duration, confirm Settings closes, and start another timed session to check the new countdown.
6. Press Control + D and confirm the timed countdown and **display awake** status. Double-tap Control to stop it.

Use a physical keyboard for these checks: synthetic input targeted at an app may not reach macOS's global event listener.

## Uninstall

Quit Upkeep from the coffee cup menu, remove it from Login Items if you added it, and move **Upkeep.app** from Applications to the Trash.
