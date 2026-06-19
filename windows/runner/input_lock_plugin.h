#ifndef RUNNER_INPUT_LOCK_PLUGIN_H_
#define RUNNER_INPUT_LOCK_PLUGIN_H_

#include <flutter/binary_messenger.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <atomic>
#include <chrono>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

// InputLockPlugin implements the
// `video.divine.lucent/input_lock/{methods,events}` platform-channel contract
// on Windows using low-level global hooks (WH_KEYBOARD_LL [+ WH_MOUSE_LL]).
//
// Threading model:
//   * The hooks are installed on, and their callbacks fire on, the Flutter
//     platform/UI thread (the runner's WinMain message-pumping thread). All
//     Flutter channel access from the hook callback is therefore already on
//     the correct thread and needs no marshaling.
//   * A worker "heartbeat" thread drives the hold-to-unlock progress + the
//     completion check. It NEVER touches the Flutter sink directly; it posts a
//     custom window message (kWmInputLockTick) to the Flutter root HWND, and
//     the WindowProc forwards that to the plugin on the platform thread.
//
// There is exactly one live instance, owned by FlutterWindow; the low-level
// hook callbacks are static and dispatch to that instance via a file-scope
// pointer (LL hooks give us no user-data parameter).
class InputLockPlugin {
 public:
  // The window message the heartbeat thread posts to the platform thread.
  // WPARAM/LPARAM are unused; the plugin reads its own state.
  static const UINT kWmInputLockTick;

  // |messenger| is flutter_controller_->engine()->messenger().
  // |host_window| is the top-level runner HWND (used as the post target for
  // the heartbeat message). Both must outlive the plugin.
  InputLockPlugin(flutter::BinaryMessenger* messenger, HWND host_window);
  ~InputLockPlugin();

  InputLockPlugin(const InputLockPlugin&) = delete;
  InputLockPlugin& operator=(const InputLockPlugin&) = delete;

  // Called by FlutterWindow::MessageHandler when it sees kWmInputLockTick.
  // Runs on the platform thread. Emits unlockProgress / triggers userGesture
  // release as appropriate.
  void OnHeartbeatTick();

  // Tear everything down (called from dtor / OnDestroy). Idempotent.
  void Shutdown();

 private:
  enum class Gesture { kHoldSpace, kHoldEsc, kHoldEscOrSpace };

  // ---- Method handlers (platform thread) ----
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  bool Lock(bool swallow_pointer, bool allow_mouse_move);
  bool Unlock(const std::string& reason);
  bool ConfigureUnlockGesture(const std::string& gesture, int hold_ms,
                              bool require_key_up_reset);

  // ---- Event emission (platform thread only) ----
  void EmitLockEngaged(bool swallows_pointer);
  void EmitLockReleased(const std::string& reason, const std::string& detail);
  void EmitUnlockProgress(double value);
  void EmitPermissionChanged(const std::string& status);

  // ---- Hook plumbing ----
  bool InstallHooks(bool swallow_pointer);
  void RemoveHooks();

  // Returns true if the event should be swallowed (hook returns 1).
  // Updates gesture/hold state. Runs on the platform thread (hook callback).
  bool OnLowLevelKeyboard(WPARAM message, const KBDLLHOOKSTRUCT* info);
  bool OnLowLevelMouse(WPARAM message, const MSLLHOOKSTRUCT* info);

  // Static trampolines registered with SetWindowsHookEx.
  static LRESULT CALLBACK KeyboardProc(int code, WPARAM wparam, LPARAM lparam);
  static LRESULT CALLBACK MouseProc(int code, WPARAM wparam, LPARAM lparam);

  // Heartbeat worker.
  void HeartbeatLoop();
  void StartHeartbeat();
  void StopHeartbeat();

  // Is |vk| one of the configured unlock keys?
  bool IsUnlockKey(DWORD vk) const;

  flutter::BinaryMessenger* messenger_;
  HWND host_window_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  // Hook handles (set/cleared on platform thread).
  HHOOK keyboard_hook_ = nullptr;
  HHOOK mouse_hook_ = nullptr;

  // ---- Lock / gesture state ----
  // Accessed by the hook callback (platform thread) and the heartbeat thread
  // (worker). Kept atomic so the worker can read a coherent snapshot without
  // taking a lock inside the latency-sensitive hook path.
  std::atomic<bool> locked_{false};
  std::atomic<bool> swallow_pointer_{true};
  std::atomic<bool> allow_mouse_move_{false};

  Gesture gesture_ = Gesture::kHoldSpace;        // platform thread only
  std::atomic<long long> hold_duration_ms_{2500};
  bool require_key_up_reset_ = true;             // platform thread only
  bool gesture_configured_ = false;              // platform thread only

  // Monotonic ms timestamp when the unlock key went (and stayed) down; 0 = not
  // holding. Written by the hook, read by the heartbeat thread.
  std::atomic<long long> hold_start_ms_{0};
  // Set by the heartbeat thread when progress reaches 1.0, consumed on the
  // platform thread to emit lockReleased(userGesture).
  std::atomic<bool> unlock_completed_{false};
  // Last progress value we emitted, to throttle the event stream.
  double last_emitted_progress_ = -1.0;

  // Heartbeat thread lifecycle.
  std::thread heartbeat_thread_;
  std::atomic<bool> heartbeat_run_{false};

  static long long NowMs();
};

#endif  // RUNNER_INPUT_LOCK_PLUGIN_H_
