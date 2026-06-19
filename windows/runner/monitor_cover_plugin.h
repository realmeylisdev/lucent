#ifndef RUNNER_MONITOR_COVER_PLUGIN_H_
#define RUNNER_MONITOR_COVER_PLUGIN_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>
#include <vector>

// MonitorCoverPlugin implements the `video.divine.lucent/monitor_cover`
// platform-channel contract on Windows. It mirrors the macOS MonitorCoverPlugin
// (MainFlutterWindow.swift): on "cover" it blacks out every NON-primary monitor
// with a borderless, always-on-top, solid-color Win32 window; on "release" it
// destroys those windows.
//
// Methods:
//   "cover"   args { colorHex: String like "#rrggbb" } -> bool
//   "release"                                            -> bool
//
// Threading: all method calls and all window creation/destruction happen on the
// Flutter platform/UI thread (the runner's WinMain message-pumping thread), so
// the cover windows share that thread's message pump and no marshaling is
// needed. There is exactly one live instance, owned by FlutterWindow.
class MonitorCoverPlugin {
 public:
  // |messenger| is flutter_controller_->engine()->messenger(). It must outlive
  // the plugin.
  explicit MonitorCoverPlugin(flutter::BinaryMessenger* messenger);
  ~MonitorCoverPlugin();

  MonitorCoverPlugin(const MonitorCoverPlugin&) = delete;
  MonitorCoverPlugin& operator=(const MonitorCoverPlugin&) = delete;

  // Tear down all cover windows + resources. Idempotent. Called from the dtor
  // and from FlutterWindow::OnDestroy.
  void Shutdown();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Create one borderless top-most window over every non-primary monitor,
  // painted |color|. Releases any existing covers first.
  bool Cover(COLORREF color);
  // Destroy all cover windows + the brush. Idempotent.
  void Release();

  // EnumDisplayMonitors callback: appends each monitor's RECT to |monitors_|.
  static BOOL CALLBACK EnumMonitorProc(HMONITOR monitor, HDC hdc, LPRECT rect,
                                       LPARAM lparam);

  // WindowProc for the cover windows; paints the background brush.
  static LRESULT CALLBACK CoverWndProc(HWND hwnd, UINT message, WPARAM wparam,
                                       LPARAM lparam);

  // Parses "#rrggbb" (or "rrggbb") into a COLORREF. Returns black on bad input.
  static COLORREF ParseHexColor(const std::string& hex);

  flutter::BinaryMessenger* messenger_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;

  // The window class is registered lazily on first Cover() and unregistered in
  // Shutdown(). Stored so we only register once per process.
  bool class_registered_ = false;
  // Solid background brush for the current cover color; recreated each Cover().
  HBRUSH background_brush_ = nullptr;
  // All live cover windows.
  std::vector<HWND> cover_windows_;
};

#endif  // RUNNER_MONITOR_COVER_PLUGIN_H_
