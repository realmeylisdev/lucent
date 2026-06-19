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
| Cleaning modes (Screen / Keyboard / Full) + countdown ring + guided wipe | ✅ | ✅ | ✅ |
| Display Lab — 26 test patterns + dead/stuck-pixel fixer | ✅ | ✅ | ✅ |
| Brightness boost (`screen_brightness`) | ✅ | ✅ | ⚠️ no-op (unsupported) |
| Accessibility permission onboarding | ✅ | n/a | n/a |
| Settings (grouped) + press-to-record hotkey | ✅ | ✅ | ✅ |
| Light / Dark / System theme | ✅ | ✅ | ✅ |
| About / help screen | ✅ | ✅ | ✅ |
| Multi-monitor **visual** blackout | ✅ native | ✅ native² | ✅ native² |
| Menu-bar / tray + global hotkey | ✅ | ✅³ | ✅³ |

¹ Windows & Linux native input-lock now **compiles in CI** on real Windows /
Linux runners (`WH_KEYBOARD_LL`; X11 `XGrabKeyboard` + Wayland shortcut-inhibit).
Runtime behavior on those platforms is not yet interactively verified.
² Every non-primary display is blacked out by a native cover window per platform:
macOS `NSWindow`, Windows Win32 (`EnumDisplayMonitors`), Linux `GtkWindow` (X11
positions precisely; Wayland degrades — absolute placement is compositor-
restricted). Build-verified on all three via CI; runtime-verified on macOS.
³ Activated at the app root (`AppShell`): a menu-bar / tray item (Start Cleaning
/ Display Lab / Settings / Quit) and a global start-cleaning hotkey. Verified on
macOS; Windows/Linux pending an on-platform check.

macOS builds & runs; `flutter analyze` is clean under `very_good_analysis`; 99
unit/widget tests pass (plus macOS-guarded golden tests for the painters); CI
builds **all three desktop platforms** (macOS, Windows, Linux) and runs analyze +
tests on every push.

## Architecture (VGV, feature-first)

```
lib/
  app/            App widget, theme, bootstrap (DI)
  core/
    constants/    channel + method names (the InputLock contract)
    models/       UnlockKey
    platform/     NativeLockController (MethodChannel + EventChannel facade)
    services/     MultiMonitorCover, Brightness, AutoStart, Hotkey, Tray
  features/
    home/         landing screen
    cleaning/     modes (screen/keyboard/full) + countdown ring + guided-wipe
    display_lab/  26 test patterns (8 categories) + dead/stuck-pixel fixer
    settings/     persisted settings cubit + repository + model
    accessibility/ macOS permission onboarding
    about/        app version + GitHub link + license
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

## Releases

Releases are built by [`.github/workflows/release.yml`](.github/workflows/release.yml).

### Cutting a release

Push a tag matching `v*`:

```bash
git tag v1.0.0
git push origin v1.0.0
```

(You can also run the workflow manually from the Actions tab via
**workflow_dispatch**.) The pipeline builds all three desktop targets and
produces:

| Platform | Artifact |
| --- | --- |
| macOS  | `lucent-macos.dmg` |
| Windows | `lucent-windows-x64.zip` |
| Linux  | `lucent-linux-x64.tar.gz` |

It then creates a **draft** GitHub Release for the tag with auto-generated
notes and attaches all three artifacts. Nothing is published until you open the
draft in the GitHub UI and click **Publish**.

### macOS signing & notarization (optional secrets)

Lucent ships **non-sandboxed** with the hardened runtime because its
`CGEventTap` needs Accessibility / Input-Monitoring trust. For the `.app` to run
on other people's Macs without Gatekeeper blocking it, the DMG must be
**Developer-ID signed and notarized**. That requires the maintainer's Apple
credentials, configured as GitHub repository secrets (Settings → Secrets and
variables → Actions). All are **optional** — see the no-secrets behavior below.

Signing (all four required to enable signing):

| Secret | Purpose |
| --- | --- |
| `MACOS_CERT_P12_BASE64` | Base64 of the exported Developer ID Application certificate + private key (`.p12`). |
| `MACOS_CERT_PASSWORD` | Password protecting that `.p12` export. |
| `MACOS_KEYCHAIN_PASSWORD` | Arbitrary password used to create the temporary CI keychain. |
| `MACOS_SIGN_IDENTITY` | The signing identity string, e.g. `Developer ID Application: Your Name (TEAMID)`. |

Notarization — provide **one** of these two sets (App Store Connect API key is
preferred):

| Secret | Purpose |
| --- | --- |
| `AC_API_KEY_ID` | App Store Connect API key ID. |
| `AC_API_ISSUER_ID` | App Store Connect API issuer ID. |
| `AC_API_KEY_BASE64` | Base64 of the `.p8` API key file. |

or

| Secret | Purpose |
| --- | --- |
| `APPLE_ID` | Apple ID email used for notarization. |
| `APPLE_TEAM_ID` | Apple Developer Team ID. |
| `APPLE_APP_PASSWORD` | App-specific password for that Apple ID. |

### Without the secrets

If the signing secrets are **not** configured, the release still builds and
uploads — the macOS DMG is just **ad-hoc signed (unsigned)**. Gatekeeper will
block it on other Macs. To run it, users must remove the quarantine attribute:

```bash
xattr -dr com.apple.quarantine /Applications/lucent.app
```

(If signing secrets are present but notarization secrets are not, the DMG is
Developer-ID signed but not notarized; Gatekeeper may still warn.) The Windows
zip and Linux tar.gz are unsigned regardless.
