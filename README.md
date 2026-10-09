# Upkeep ☕

Keep your Mac awake while you work, download, or wait for something to finish.

Upkeep is a small native macOS menu bar app powered by Apple's `caffeinate` command. Start a timed session with a double-tap of Control, or keep your Mac awake indefinitely with Control + I. A coffee cup in the menu bar shows whether Upkeep is active.

## Features

- Timed sessions with a default duration of **120 minutes** (7,200 seconds).
- Unlimited sessions that run until you stop them.
- Duration settings in **minutes or hours**, including fractional values.
- Global keyboard shortcuts for starting, stopping, and opening Settings.
- A timed **display-awake** mode to keep the screen from going black through idle display sleep.
- An amber coffee cup with a countdown or **∞** while active; an outlined cup while off.
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
| **Control + D (⌃ D)** | Start a timed session that keeps both the Mac and display awake, using the saved duration |

Double-tap Control with two quick press-and-release taps, no more than **450 ms** apart. Either Control key works. A long hold, another key or modifier, or a mouse click cancels the double-tap sequence. For Settings, press Control and Shift together; either order works.

The shortcuts are currently fixed. The listener is passive, so a shortcut can also trigger the focused app's usual action.

Pressing Control + I during an unlimited session leaves it running. Double-tap Control, choose **Stop Upkeep session** from the menu, or quit Upkeep to stop it.

**Control + D** starts a fresh timed session with display sleep prevention. It replaces any current session and uses the same duration as double-Control. Holding the keys does not repeatedly restart the timer. The countdown remains amber, and the menu, tooltip, and Settings identify **display awake** mode. Double-Control stops it; its sleep prevention also ends when the timer expires or you quit Upkeep. Switching to Control + I releases display sleep prevention and starts the usual unlimited session.

### Change the duration

Open Settings from the menu or with **Control + Shift**. Enter a positive number and choose **Minutes** or **Hours** from the dropdown:

| Setting | Timed session length |
| --- | --- |
| 30 Minutes | Half an hour |
| 120 Minutes | Two hours (the initial default) |
| 1.5 Hours | Ninety minutes |

Settings opens in **Minutes** by default. Changing the unit converts the displayed value, preserving the duration. Click **Save duration** to save and close the window. Invalid input leaves the window open so you can correct it.

Your duration is remembered between launches and applies to the **next timed session**. Saving a duration does not change a session already running. Unlimited sessions have no timeout.

### Read the menu bar indicator

| Indicator | State |
| --- | --- |
| Outlined coffee cup | Upkeep is off |
| Amber cup and countdown | A timed session is running |
| Amber cup and **∞** | An unlimited session is running |

Hold **Command** and drag the icon to reposition it in the menu bar.

Standard timed and unlimited sessions prevent **idle system sleep** and let the display sleep according to macOS settings. Control + D additionally prevents **idle display sleep**, using `caffeinate -di -t <seconds>`. Standard timed sessions use `caffeinate -t <seconds>`; unlimited sessions use `caffeinate`. These modes do not override lid-close behavior or explicit sleep/lock actions. Other caffeinate processes appear separately in the menu and tooltip; Upkeep stops only its own process.

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

These checks cover duration conversion and validation, saving and closing Settings, timed expiry, unlimited sessions, session transitions, process cleanup, double-Control detection, and shortcut action routing. Display-awake checks inspect the actual macOS display and system power assertions, verify their release on timeout and stop, and check mode transitions, key-repeat filtering, and use of the saved duration. Tests briefly open a Settings window and restore the saved duration afterward.

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
