# PinRoutes

A macOS menu bar app that keeps your static routes pinned. Routes get lost after sleep, VPN reconnects, or network changes — PinRoutes watches for that and puts them back.

## Features

- **Menu bar app** — lives in your status bar, stays out of the way
- **Route management** — add, edit, enable/disable routes with CIDR network + gateway
- **Periodic monitoring** — checks routes on a configurable interval (15s to 10min)
- **Auto-reapply** — optionally re-applies missing routes automatically
- **Notifications** — alerts you when routes go missing (if auto-reapply is off)
- **SUID helper** — install once with a single password prompt, then all route operations are silent (no more repeated password dialogs)
- **Launch at login** — optional, via macOS Login Items

## Requirements

- macOS 13.0+
- Swift 5.9+

## Install

### From GitHub Releases

Download `PinRoutes.app.zip` from the [latest release](https://github.com/Positronico/pinroutes/releases/latest), unzip, and move to `/Applications`.

Because the app is not notarized with an Apple Developer certificate, macOS will quarantine it on first run. Remove the quarantine attribute after downloading:

```bash
xattr -cr /Applications/PinRoutes.app
```

### Build from source

```bash
git clone https://github.com/Positronico/pinroutes.git
cd pinroutes
make bundle
# PinRoutes.app is now in the current directory
```

## Usage

1. **Launch** — open `PinRoutes.app`. A route icon appears in your menu bar.
2. **Add routes** — click the icon, hit **+**, enter a name, CIDR network (e.g. `10.255.0.0/16`), and gateway (e.g. `10.0.0.1`).
3. **Apply** — enabled routes are applied on launch and can be re-applied manually or automatically.
4. **Install helper** (recommended) — go to Settings tab, click **Install Helper**. Enter your password once. All future route operations happen silently without password prompts.

### SUID Helper

Every route change requires root privileges. Without the helper, macOS shows a password dialog each time. The helper (`pinroutes-helper`) is a minimal SUID binary that only knows how to run `/sbin/route` commands — nothing else. It validates all inputs before executing.

Install it from Settings, or manually:

```bash
# Build
make bundle

# Install (requires password once)
sudo cp PinRoutes.app/Contents/MacOS/pinroutes-helper /usr/local/bin/
sudo chown root:wheel /usr/local/bin/pinroutes-helper
sudo chmod 4755 /usr/local/bin/pinroutes-helper
```

Uninstall: `sudo rm /usr/local/bin/pinroutes-helper`

## Configuration

Routes and settings are stored in `~/Library/Application Support/PinRoutes/`.

| Setting | Default | Description |
|---------|---------|-------------|
| Periodic Check | On | Monitors routes on an interval |
| Check interval | 60s | How often to verify routes |
| When missing | Notify only | Notify or auto-reapply |
| Launch at Login | Off | Start on login via macOS Login Items |

## Project Structure

```
Sources/
  PinRoutes/          # Main app
    App/              # App entry point, AppDelegate
    Managers/         # RouteManager, RouteMonitor, ConfigManager
    Models/           # RouteRule, AppState, AppSettings
    Utilities/        # ShellExecutor, NetworkValidation, Log
    Views/            # SwiftUI views (MenuBar, Routes, Settings, Editor)
  PinRoutesHelper/    # SUID helper binary
    main.swift
```

## License

[MIT](LICENSE)
