import Cocoa
import ApplicationServices
import CoreGraphics

/// Owns the macOS `CGEventTap` that swallows global keyboard + pointer input,
/// detects the native hold-to-unlock gesture, and reports lifecycle/permission
/// changes to the Dart layer via the `onEvent` closure.
///
/// ## Threading model
/// The tap callback fires on a dedicated thread that we run a `CFRunLoop` on
/// (`tapThread`). The `onEvent` closure may therefore be invoked from that
/// thread; `InputLockPlugin` is responsible for hopping back to the main
/// thread before touching the `FlutterEventSink`. All mutable controller
/// state is guarded by `stateLock`.
///
/// ## What this CAN swallow
/// A session-level tap installed at `.headInsertEventTap` with
/// `listenOnly == false` (i.e. `defaultTap`) sees and can drop:
///   * `keyDown`, `keyUp`, `flagsChanged` — this includes Cmd-Q, Cmd-W,
///     Cmd-Tab, Cmd-Space (Spotlight), Option-Tab, etc. Returning `nil`
///     from the callback eats them before they reach the foreground app
///     or the WindowServer's hotkey dispatch (for app-level hotkeys).
///   * `leftMouseDown/Up`, `rightMouseDown/Up`, `otherMouseDown/Up`,
///     `mouseMoved`, `*Dragged`, `scrollWheel` — the trackpad and mouse.
///   * `NX_SYSDEFINED` (`CGEventType(rawValue: 14)`) — the system-defined
///     events that carry the media keys (play/pause, vol±, brightness) and,
///     on most keyboards, the `fn`/globe key combos. We add this to the mask
///     so brightness/volume/media keys are also eaten.
///
/// ## What this CANNOT swallow (be honest)
///   * **Touch ID / hardware power button** and the **Cmd-Ctrl-Q lock screen**
///     and **Cmd-Ctrl-power force-restart** — these are handled below the
///     event-tap layer by SecurityAgent / SMC firmware and are deliberately
///     un-interceptable.
///   * **Secure input fields** (password fields anywhere on the system) cause
///     the WindowServer to *disable* our tap with
///     `kCGEventTapDisabledByUserInput`/secure-input; we re-enable, but while
///     secure input is active our key events may not be delivered. We fail
///     safe via `lockReleased(systemForced)` if re-enable fails.
///   * **Fast user switching / login window** tears the session tap down.
///   * The bare `fn`/globe key *by itself* (no modifier) is partly handled by
///     the WindowServer before the session tap on Apple Silicon laptops; the
///     `fn`-modified function row IS caught via `flagsChanged`/`NX_SYSDEFINED`,
///     but a lone globe-key "show emoji / switch input source" press may slip
///     through on some OS versions. There is no public API to fully suppress
///     it from a session tap.
final class CGEventTapController {

  // MARK: - Public callback (set by the plugin)

  /// Invoked (possibly off the main thread) with an event-channel payload.
  var onEvent: (([String: Any]) -> Void)?

  // MARK: - State

  private let stateLock = NSLock()

  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var tapRunLoop: CFRunLoop?
  private var tapThread: Thread?

  private var locked = false
  private var swallowPointerSetting = true
  private var allowMouseMoveSetting = false

  // Unlock gesture configuration.
  private enum UnlockGesture {
    case holdSpace
    case holdEsc
    case holdEscOrSpace
  }
  private var unlockGesture: UnlockGesture = .holdSpace
  private var holdDurationMs: Int = 2500
  private var requireKeyUpReset = true

  // Gesture tracking. Mutated only from the tap thread.
  private var holdStartTime: CFAbsoluteTime?
  private var lastEmittedProgress: Double = -1
  private var progressTimer: Timer?

  // Permission watcher.
  private var permissionTimer: Timer?
  private var lastPermissionStatus: String?

  // CGKeyCodes for the keys we care about.
  private static let kVKSpace: Int64 = 49
  private static let kVKEscape: Int64 = 53

  // NX_SYSDEFINED is not exposed as a CGEventType case; raw value is 14.
  private static let nxSysDefined = CGEventType(rawValue: 14)!

  var isLocked: Bool {
    stateLock.lock(); defer { stateLock.unlock() }
    return locked
  }

  // MARK: - Permission

  /// Maps AX + IOHID Input-Monitoring state to the contract's status strings.
  func checkPermission() -> String {
    let axTrusted = AXIsProcessTrusted()
    if axTrusted {
      lastPermissionStatus = "granted"
      return "granted"
    }
    // IOHIDCheckAccess distinguishes notDetermined vs denied for the
    // Input-Monitoring TCC bucket (key event tapping needs this too).
    let hidAccess = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    let status: String
    switch hidAccess {
    case kIOHIDAccessTypeGranted:
      // AX not yet trusted but HID listen granted — still need AX for a
      // session tap, so treat as notDetermined to prompt for Accessibility.
      status = "notDetermined"
    case kIOHIDAccessTypeDenied:
      status = "denied"
    default: // kIOHIDAccessTypeUnknown
      status = "notDetermined"
    }
    lastPermissionStatus = status
    return status
  }

  /// Prompts for Accessibility and opens the relevant System Settings pane.
  func requestPermission() -> String {
    // This shows the "<App> would like to control this computer" dialog the
    // first time and adds the app to the Accessibility list (unchecked).
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [promptKey: true] as CFDictionary
    let trusted = AXIsProcessTrustedWithOptions(options)

    // Also nudge Input-Monitoring (covers key event taps on 10.15+).
    _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)

    if !trusted {
      // Deep-link straight to the Accessibility pane.
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
      ) {
        NSWorkspace.shared.open(url)
      }
    }

    let status = trusted ? "granted" : "notDetermined"
    lastPermissionStatus = status
    // The real grant happens out-of-process; permissionChanged will fire from
    // the watcher when the user toggles the checkbox.
    return status
  }

  /// Polls AX trust periodically because macOS grants happen out-of-process
  /// (the user toggles a checkbox in System Settings). There is no reliable
  /// public notification, so a low-frequency poll is the pragmatic approach.
  func startPermissionWatcher() {
    DispatchQueue.main.async {
      guard self.permissionTimer == nil else { return }
      self.permissionTimer = Timer.scheduledTimer(
        withTimeInterval: 1.0,
        repeats: true
      ) { [weak self] _ in
        guard let self = self else { return }
        let current = self.checkPermission()
        if current != self.lastEmittedPermission {
          self.lastEmittedPermission = current
          self.onEvent?(["type": "permissionChanged", "status": current])
        }
      }
    }
  }

  private var lastEmittedPermission: String?

  func stopPermissionWatcher() {
    DispatchQueue.main.async {
      self.permissionTimer?.invalidate()
      self.permissionTimer = nil
    }
  }

  // MARK: - Unlock gesture configuration

  func configureUnlockGesture(
    gesture: String,
    holdDurationMs: Int,
    requireKeyUpReset: Bool
  ) -> Bool {
    let parsed: UnlockGesture
    switch gesture {
    case "holdSpace": parsed = .holdSpace
    case "holdEsc": parsed = .holdEsc
    case "holdEscOrSpace": parsed = .holdEscOrSpace
    default: return false
    }
    guard holdDurationMs >= 250 else { return false }
    stateLock.lock()
    self.unlockGesture = parsed
    self.holdDurationMs = holdDurationMs
    self.requireKeyUpReset = requireKeyUpReset
    stateLock.unlock()
    return true
  }

  // MARK: - Lock / Unlock

  func lock(swallowPointer: Bool, allowMouseMove: Bool, displayIds: [String]) -> Bool {
    stateLock.lock()
    if locked {
      stateLock.unlock()
      return true // idempotent
    }
    stateLock.unlock()

    // A session tap requires Accessibility trust; bail early if missing.
    guard AXIsProcessTrusted() else {
      onEvent?([
        "type": "lockReleased",
        "reason": "error",
        "detail": "accessibility-not-trusted",
      ])
      return false
    }

    // Build the mask from a typed list so the Swift type-checker never has to
    // resolve a long `1 << … | 1 << …` literal chain — that trips the
    // "expression too complex to type-check" limit on some Xcode versions.
    var eventTypes: [CGEventType] = [
      .keyDown, .keyUp, .flagsChanged,
      CGEventTapController.nxSysDefined, // media / fn / brightness
    ]
    if swallowPointer {
      eventTypes += [
        .leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseUp,
        .otherMouseDown, .otherMouseUp,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        .scrollWheel,
      ]
      if !allowMouseMove {
        eventTypes.append(.mouseMoved)
      }
    }
    let mask = eventTypes.reduce(CGEventMask(0)) { result, type in
      result | (CGEventMask(1) << CGEventMask(type.rawValue))
    }

    // `refcon` carries an unmanaged pointer to self so the C callback can
    // route back into Swift.
    let selfPtr = Unmanaged.passUnretained(self).toOpaque()

    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap, // NOT listenOnly — we must be able to swallow.
      eventsOfInterest: mask,
      callback: { _, type, event, refcon in
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<CGEventTapController>
          .fromOpaque(refcon).takeUnretainedValue()
        return controller.handleTapEvent(type: type, event: event)
      },
      userInfo: selfPtr
    ) else {
      onEvent?([
        "type": "lockReleased",
        "reason": "error",
        "detail": "tap-create-failed",
      ])
      return false
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

    stateLock.lock()
    self.eventTap = tap
    self.runLoopSource = source
    self.swallowPointerSetting = swallowPointer
    self.allowMouseMoveSetting = allowMouseMove
    self.locked = true
    self.holdStartTime = nil
    self.lastEmittedProgress = -1
    stateLock.unlock()

    // Run the tap on a dedicated thread so a busy/blocked main run loop can
    // never starve event delivery (and so the WindowServer never disables the
    // tap for being unresponsive).
    let thread = Thread { [weak self] in
      guard let self = self else { return }
      let rl = CFRunLoopGetCurrent()
      self.stateLock.lock()
      self.tapRunLoop = rl
      self.stateLock.unlock()
      CFRunLoopAddSource(rl, source, .commonModes)
      CGEvent.tapEnable(tap: tap, enable: true)
      CFRunLoopRun()
    }
    thread.name = "video.divine.lucent.input_lock.tap"
    thread.qualityOfService = .userInteractive
    self.tapThread = thread
    thread.start()

    onEvent?([
      "type": "lockEngaged",
      "swallowsPointer": swallowPointer,
      "timestampMs": Int(Date().timeIntervalSince1970 * 1000),
    ])
    return true
  }

  @discardableResult
  func unlock(reason: String) -> Bool {
    stateLock.lock()
    guard locked else {
      stateLock.unlock()
      return false // no-op; safe.
    }
    let tap = eventTap
    let source = runLoopSource
    let rl = tapRunLoop
    locked = false
    eventTap = nil
    runLoopSource = nil
    tapRunLoop = nil
    holdStartTime = nil
    stateLock.unlock()

    if let tap = tap {
      CGEvent.tapEnable(tap: tap, enable: false)
    }
    if let rl = rl, let source = source {
      CFRunLoopRemoveSource(rl, source, .commonModes)
      CFRunLoopStop(rl)
    }
    tapThread = nil

    stopProgressThrottle()

    onEvent?(["type": "lockReleased", "reason": reason])
    return true
  }

  // MARK: - Tap callback core

  /// Returns `nil` (via Unmanaged?) to swallow the event, or the event to let
  /// it pass. Runs on the tap thread.
  private func handleTapEvent(
    type: CGEventType,
    event: CGEvent
  ) -> Unmanaged<CGEvent>? {
    // Handle the WindowServer disabling our tap.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      let cause = (type == .tapDisabledByTimeout) ? "timeout" : "userInput"
      reEnableTap(cause: cause)
      return nil
    }

    // Keyboard: drive the unlock gesture state machine.
    if type == .keyDown || type == .keyUp {
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
      let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
      if type == .keyDown {
        handleKeyDown(keyCode: keyCode, isAutorepeat: isAutorepeat)
      } else {
        handleKeyUp(keyCode: keyCode)
      }
      // Always swallow.
      return nil
    }

    // Everything else in our mask (flagsChanged, pointer, scroll, media/fn):
    // swallow unconditionally. The user can ONLY exit via the unlock gesture.
    return nil
  }

  // MARK: - Unlock gesture state machine (tap thread)

  private func isUnlockKey(_ keyCode: Int64) -> Bool {
    switch unlockGesture {
    case .holdSpace: return keyCode == CGEventTapController.kVKSpace
    case .holdEsc: return keyCode == CGEventTapController.kVKEscape
    case .holdEscOrSpace:
      return keyCode == CGEventTapController.kVKSpace
        || keyCode == CGEventTapController.kVKEscape
    }
  }

  private func handleKeyDown(keyCode: Int64, isAutorepeat: Bool) {
    guard isUnlockKey(keyCode) else {
      // A non-unlock key during a hold cancels it (any other key resets).
      if holdStartTime != nil {
        resetHold()
      }
      return
    }
    if isAutorepeat { return } // ignore OS key-repeat events.
    if holdStartTime == nil {
      holdStartTime = CFAbsoluteTimeGetCurrent()
      startProgressThrottle()
    }
  }

  private func handleKeyUp(keyCode: Int64) {
    guard isUnlockKey(keyCode) else { return }
    if requireKeyUpReset {
      resetHold()
    }
  }

  private func resetHold() {
    holdStartTime = nil
    stopProgressThrottle()
    emitProgress(0.0, force: true)
  }

  private func currentProgress() -> Double {
    guard let start = holdStartTime else { return 0.0 }
    let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
    return min(1.0, max(0.0, elapsedMs / Double(holdDurationMs)))
  }

  /// A ~60fps timer (on the tap thread's run loop) that samples hold progress.
  private func startProgressThrottle() {
    // Scheduled on the tap run loop so it ticks alongside event delivery.
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.progressTimer?.invalidate()
      self.progressTimer = Timer.scheduledTimer(
        withTimeInterval: 1.0 / 60.0,
        repeats: true
      ) { [weak self] _ in
        self?.tickProgress()
      }
    }
  }

  private func stopProgressThrottle() {
    DispatchQueue.main.async { [weak self] in
      self?.progressTimer?.invalidate()
      self?.progressTimer = nil
    }
  }

  private func tickProgress() {
    let progress = currentProgress()
    emitProgress(progress, force: false)
    if progress >= 1.0 {
      stopProgressThrottle()
      // Completing the hold tears down the tap and reports a user gesture.
      unlock(reason: "userGesture")
    }
  }

  /// Throttles emission to meaningful deltas (~1%).
  private func emitProgress(_ value: Double, force: Bool) {
    if !force && abs(value - lastEmittedProgress) < 0.01 { return }
    lastEmittedProgress = value
    let gestureName: String
    switch unlockGesture {
    case .holdSpace: gestureName = "holdSpace"
    case .holdEsc: gestureName = "holdEsc"
    case .holdEscOrSpace: gestureName = "holdEscOrSpace"
    }
    onEvent?([
      "type": "unlockProgress",
      "value": value,
      "gesture": gestureName,
    ])
  }

  // MARK: - Tap re-enable

  private func reEnableTap(cause: String) {
    stateLock.lock()
    let tap = eventTap
    stateLock.unlock()

    guard let tap = tap else {
      onEvent?([
        "type": "tapDisabled", "cause": cause, "reEnabled": false,
      ])
      onEvent?([
        "type": "lockReleased", "reason": "systemForced", "detail": cause,
      ])
      return
    }

    CGEvent.tapEnable(tap: tap, enable: true)
    let reEnabled = CGEvent.tapIsEnabled(tap: tap)
    onEvent?([
      "type": "tapDisabled", "cause": cause, "reEnabled": reEnabled,
    ])
    if !reEnabled {
      // Could not recover (e.g. perm revoked or persistent secure input).
      // Fail safe: drop out of cleaning rather than leaving a half-lock.
      unlock(reason: "systemForced")
    }
  }
}
