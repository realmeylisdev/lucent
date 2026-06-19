#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "input_lock_plugin.h"
#include "monitor_cover_plugin.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Lucent's native input-lock plugin (WH_KEYBOARD_LL / WH_MOUSE_LL).
  std::unique_ptr<InputLockPlugin> input_lock_plugin_;

  // Lucent's native monitor-cover plugin (blacks out non-primary displays).
  std::unique_ptr<MonitorCoverPlugin> monitor_cover_plugin_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
