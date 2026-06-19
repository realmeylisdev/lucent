# Lucent

[![CI](https://github.com/realmeylisdev/lucent/actions/workflows/ci.yml/badge.svg)](https://github.com/realmeylisdev/lucent/actions/workflows/ci.yml)

A cross-platform (macOS / Windows / Linux) Flutter **desktop** screen-cleaning
utility with a **real native OS-level input lock** — a superior alternative to
the Mac App Store "Pristine Screen" and similar apps that rely only on Flutter's
`RawKeyboardListener` and therefore **cannot** block Cmd-Q, Cmd-Tab / Alt-Tab,
the fn row, the globe key, media keys, or the trackpad.

Lucent installs a genuine session-level event tap, so it swallows those keys (to
the limit the OS allows) and the user can only leave by performing a deliberate
**hold-to-unlock** gesture detected inside the native hook itself.

## Status

| Capability | macOS | Windows | Linux |
|---|---|---|---|
| Native keyboard + trackpad lock | ✅ builds/runs | ✅ builds in CI¹ | ✅ builds in CI¹ |
| Hold-to-unlock (native gesture + progress ring) | ✅ | ✅¹ | ✅¹ |
| Fullscreen black cleaning mode | ✅ | ✅ | ✅ |
| Display test patterns (smudge / dead-pixel) | ✅ | ✅ | ✅ |
| Brightness boost (`screen_brightness`) | ✅ | ✅ | ⚠️ no-op (unsupported) |
| Accessibility permission onboarding | ✅ | n/a | n/a |
| Settings (persisted) | ✅ | ✅ | ✅ |
| Multi-monitor **visual** blackout | ✅ native (NSWindow/screen) | ⏳ deferred² | ⏳² |
| Menu-bar / tray + global hotkey | ✅ | ✅³ | ✅³ |

¹ Windows & Linux native input-lock now **compiles in CI** on real Windows /
Linux runners (`WH_KEYBOARD_LL`; X11 `XGrabKeyboard` + Wayland shortcut-inhibit).
Runtime behavior on those platforms is not yet interactively verified.
² macOS blacks out every non-main display natively (`MonitorCoverPlugin` → one
borderless black `NSWindow` per `NSScreen`). Windows/Linux are deferred and need
their own native cover windows. The input lock already covers **all** displays
regardless — this is purely visual.
³ Activated at the app root (`AppShell`): a menu-bar / tray item (Start Cleaning
/ Display Test / Settings / Quit) and a global start-cleaning hotkey. Verified on
macOS; Windows/Linux pending an on-platform check.

macOS builds & runs; `flutter analyze` is clean under `very_good_analysis`; unit
tests pass; CI builds **all three desktop platforms** (macOS, Windows, Linux) and
runs analyze + tests on every push.

## Architecture (VGV, feature-first)

```
lib/
  app/            App widget, theme, bootstrap (DI)
  core/
    constants/    channel + method names (the InputLock contract)
    models/       UnlockKey, TestPattern
    platform/     NativeLockController (MethodChannel + EventChannel facade)
    services/     MultiMonitorCover, Brightness, AutoStart, Hotkey, Tray
  features/
    home/         landing screen
    cleaning/     fullscreen clean mode + cubit + unlock ring
    display_test/ test patterns + cubit
    settings/     persisted settings cubit + repository + model
    accessibility/ macOS permission onboarding
```

State: `flutter_bloc` cubits, immutable `Equatable` states, constructor DI.

## Two cross-cutting constraints

### 1. Swallowed-key unlock

The native hook swallows keystrokes, so **Flutter never receives the unlock
keypress**. The native layer detects the unlock hold-gesture itself, streams
`unlockProgress` (0..1) over the `EventChannel`, then emits
`lockReleased(reason: userGesture)`. `CleaningCubit` only *reacts* to that
stream — it never listens for keys. See
`lib/core/platform/native_lock_controller.dart` and, on macOS,
`macos/Runner/InputLock/CGEventTapController.swift`.

### 2. macOS sandbox vs Accessibility

A `CGEventTap` requires Accessibility / Input-Monitoring (`AXIsProcessTrusted`),
which is **incompatible with the Mac App Store App Sandbox**. Therefore Lucent
ships **outside** the App Store as a **notarized, hardened-runtime,
non-sandboxed** app on macOS:

- Hardened Runtime ON, App Sandbox **OFF** (`macos/Runner/*.entitlements`).
- Codesign with a Developer ID Application certificate, then `notarytool` +
  `stapler`.
- The first time the lock engages, macOS prompts for Accessibility; the in-app
  onboarding deep-links to System Settings ▸ Privacy & Security ▸ Accessibility.
- Windows: no special permission for the `WH_KEYBOARD_LL` hook (cannot block
  Ctrl-Alt-Del / Win+L — OS-reserved). Linux: X11 grab works; Wayland restricts
  global grabs (uses the shortcut-inhibit protocol where available).

## Native contract (shared by all three platforms)

Method channel `video.divine.lucent/input_lock/methods`:
`checkPermission()`, `requestPermission()`,
`configureUnlockGesture({gesture, holdDurationMs, requireKeyUpReset})`,
`lock({swallowPointer, allowMouseMove, displayIds})`, `unlock({reason})`,
`isLocked()`.

Event channel `video.divine.lucent/input_lock/events` emits maps with a `type`:
`unlockProgress {value}`, `lockReleased {reason}` (`userGesture` |
`systemForced` | `programmatic` | `error`), `lockEngaged`, `permissionChanged
{status}`, `tapDisabled {cause, reEnabled}`.

## Build & run

```bash
flutter pub get
flutter run -d macos        # or: flutter build macos --release
# flutter run -d windows
# flutter run -d linux
flutter analyze
flutter test
```

> ⚠️ Running engages a real global input tap. Grant Accessibility when prompted;
> to exit cleaning mode, **hold the unlock key** (default Esc) for ~2.5s.
