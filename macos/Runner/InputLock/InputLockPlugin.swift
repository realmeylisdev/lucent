import Cocoa
import FlutterMacOS

/// macOS implementation of the `video.divine.lucent/input_lock` platform
/// channel contract.
///
/// This is a self-contained `FlutterPlugin` that owns:
///   * the method channel  `video.divine.lucent/input_lock/methods`
///   * the event channel    `video.divine.lucent/input_lock/events`
///
/// It delegates the actual OS-level event tap to `CGEventTapController`.
///
/// Register it from `MainFlutterWindow.awakeFromNib()`:
///
///     InputLockPlugin.register(with: flutterViewController)
///
/// All event-channel emissions are marshalled onto the main thread, because
/// `FlutterEventSink` is only safe to call from the platform (main) thread,
/// while the CGEventTap callback runs on a dedicated run-loop thread.
public final class InputLockPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

  // MARK: Channel identifiers (must match the Dart contract exactly).
  private static let methodChannelName = "video.divine.lucent/input_lock/methods"
  private static let eventChannelName = "video.divine.lucent/input_lock/events"

  private let controller = CGEventTapController()
  private var eventSink: FlutterEventSink?

  // MARK: - Registration

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = InputLockPlugin()

    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger
    )
    eventChannel.setStreamHandler(instance)

    // Bridge the controller's callbacks back out over the event channel.
    instance.controller.onEvent = { [weak instance] payload in
      instance?.emit(payload)
    }
  }

  // MARK: - FlutterStreamHandler

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    // Start the permission watcher only while Dart is listening.
    controller.startPermissionWatcher()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    controller.stopPermissionWatcher()
    return nil
  }

  /// Marshals an event payload to the main thread and forwards it to Dart.
  private func emit(_ payload: [String: Any]) {
    if Thread.isMainThread {
      eventSink?(payload)
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.eventSink?(payload)
      }
    }
  }

  // MARK: - FlutterPlugin (method handling)

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkPermission":
      result(controller.checkPermission())

    case "requestPermission":
      result(controller.requestPermission())

    case "configureUnlockGesture":
      guard let args = call.arguments as? [String: Any] else {
        result(false)
        return
      }
      let gesture = (args["gesture"] as? String) ?? "holdSpace"
      let holdMs = (args["holdDurationMs"] as? Int) ?? 2500
      let requireKeyUpReset = (args["requireKeyUpReset"] as? Bool) ?? true
      let accepted = controller.configureUnlockGesture(
        gesture: gesture,
        holdDurationMs: holdMs,
        requireKeyUpReset: requireKeyUpReset
      )
      result(accepted)

    case "lock":
      let args = call.arguments as? [String: Any] ?? [:]
      let swallowPointer = (args["swallowPointer"] as? Bool) ?? true
      let allowMouseMove = (args["allowMouseMove"] as? Bool) ?? false
      let displayIds = (args["displayIds"] as? [String]) ?? []
      let engaged = controller.lock(
        swallowPointer: swallowPointer,
        allowMouseMove: allowMouseMove,
        displayIds: displayIds
      )
      result(engaged)

    case "unlock":
      let args = call.arguments as? [String: Any] ?? [:]
      let reason = (args["reason"] as? String) ?? "programmatic"
      result(controller.unlock(reason: reason))

    case "isLocked":
      result(controller.isLocked)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
