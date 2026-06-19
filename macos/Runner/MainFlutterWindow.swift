import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Lucent's in-repo native plugins.
    InputLockPlugin.register(
      with: flutterViewController.registrar(forPlugin: "InputLockPlugin")
    )
    MonitorCoverPlugin.register(
      with: flutterViewController.registrar(forPlugin: "MonitorCoverPlugin")
    )

    super.awakeFromNib()
  }
}

/// Blacks out every NON-main display with a borderless cover window, so a
/// cleaning session visually clears all attached monitors. The native input
/// lock already covers input on every display; these windows are the visual
/// half. Channel: `video.divine.lucent/monitor_cover` (`cover` / `release`).
public final class MonitorCoverPlugin: NSObject, FlutterPlugin {
  private static let channelName = "video.divine.lucent/monitor_cover"
  private var covers: [NSWindow] = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MonitorCoverPlugin()
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "cover":
      let args = call.arguments as? [String: Any] ?? [:]
      let hex = (args["colorHex"] as? String) ?? "#000000"
      cover(colorHex: hex)
      result(true)
    case "release":
      release()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func cover(colorHex: String) {
    release()
    let color = NSColor(hex: colorHex) ?? .black
    let mainScreen = NSScreen.main
    for screen in NSScreen.screens where screen != mainScreen {
      let window = NSWindow(
        contentRect: screen.frame,
        styleMask: .borderless,
        backing: .buffered,
        defer: false
      )
      window.isOpaque = true
      window.backgroundColor = color
      window.level = .screenSaver
      window.ignoresMouseEvents = true
      window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
      window.setFrame(screen.frame, display: true)
      window.orderFrontRegardless()
      covers.append(window)
    }
  }

  private func release() {
    for window in covers {
      window.orderOut(nil)
    }
    covers.removeAll()
  }
}

private extension NSColor {
  /// Parses `#rrggbb` (or `rrggbb`) into an opaque NSColor.
  convenience init?(hex: String) {
    var value = hex
    if value.hasPrefix("#") { value.removeFirst() }
    guard value.count == 6, let rgb = Int(value, radix: 16) else { return nil }
    self.init(
      red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
      green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
      blue: CGFloat(rgb & 0xFF) / 255.0,
      alpha: 1.0
    )
  }
}
