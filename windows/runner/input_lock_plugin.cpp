#include "input_lock_plugin.h"

#include <flutter/encodable_value.h>

#include <variant>

using flutter::EncodableMap;
using flutter::EncodableValue;

namespace {

// LL hooks provide no user-data pointer, so the static trampolines reach the
// live instance through this file-scope pointer. There is exactly one plugin
// instance (owned by FlutterWindow) for the lifetime of the process.
InputLockPlugin* g_instance = nullptr;

const char kMethodChannelName[] = "video.divine.lucent/input_lock/methods";
const char kEventChannelName[] = "video.divine.lucent/input_lock/events";

// Helpers to pull typed values out of an EncodableMap argument.
const EncodableValue* ValueFor(const EncodableMap& map, const char* key) {
  auto it = map.find(EncodableValue(std::string(key)));
  return it == map.end() ? nullptr : &it->second;
}

bool GetBool(const EncodableMap& map, const char* key, bool fallback) {
  const EncodableValue* v = ValueFor(map, key);
  if (v && std::holds_alternative<bool>(*v)) return std::get<bool>(*v);
  return fallback;
}

int GetInt(const EncodableMap& map, const char* key, int fallback) {
  const EncodableValue* v = ValueFor(map, key);
  if (v && std::holds_alternative<int>(*v)) return std::get<int>(*v);
  if (v && std::holds_alternative<int64_t>(*v))
    return static_cast<int>(std::get<int64_t>(*v));
  return fallback;
}

std::string GetString(const EncodableMap& map, const char* key,
                      const std::string& fallback) {
  const EncodableValue* v = ValueFor(map, key);
  if (v && std::holds_alternative<std::string>(*v))
    return std::get<std::string>(*v);
  return fallback;
}

long long Clamp01ToMs(long long v) { return v < 0 ? 0 : v; }

}  // namespace

// Registered once; a process-unique message id for the heartbeat post.
const UINT InputLockPlugin::kWmInputLockTick =
    ::RegisterWindowMessageW(L"video.divine.lucent.input_lock.tick");

long long InputLockPlugin::NowMs() {
  using namespace std::chrono;
  return duration_cast<milliseconds>(steady_clock::now().time_since_epoch())
      .count();
}

InputLockPlugin::InputLockPlugin(flutter::BinaryMessenger* messenger,
                                 HWND host_window)
    : messenger_(messenger), host_window_(host_window) {
  g_instance = this;

  method_channel_ =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          messenger_, kMethodChannelName,
          &flutter::StandardMethodCodec::GetInstance());
  method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  event_channel_ =
      std::make_unique<flutter::EventChannel<EncodableValue>>(
          messenger_, kEventChannelName,
          &flutter::StandardMethodCodec::GetInstance());
  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<EncodableValue>>(
      [this](const EncodableValue*,
             std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
        event_sink_ = std::move(events);
        return nullptr;
      },
      [this](const EncodableValue*)
          -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
        event_sink_.reset();
        return nullptr;
      });
  event_channel_->SetStreamHandler(std::move(handler));
}

InputLockPlugin::~InputLockPlugin() {
  Shutdown();
  if (g_instance == this) g_instance = nullptr;
}

void InputLockPlugin::Shutdown() {
  StopHeartbeat();
  RemoveHooks();
  locked_.store(false);
}

// ----------------------------------------------------------------------------
// Method dispatch (platform thread)
// ----------------------------------------------------------------------------
void InputLockPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const auto* args = std::get_if<EncodableMap>(call.arguments());
  EncodableMap empty;
  const EncodableMap& a = args ? *args : empty;

  if (method == "checkPermission" || method == "requestPermission") {
    // Windows never needs a permission for a same-process LL hook.
    EmitPermissionChanged("notRequired");
    result->Success(EncodableValue(std::string("notRequired")));
    return;
  }

  if (method == "configureUnlockGesture") {
    const std::string gesture = GetString(a, "gesture", "holdSpace");
    const int hold_ms = GetInt(a, "holdDurationMs", 2500);
    const bool reset = GetBool(a, "requireKeyUpReset", true);
    const bool ok = ConfigureUnlockGesture(gesture, hold_ms, reset);
    result->Success(EncodableValue(ok));
    return;
  }

  if (method == "lock") {
    const bool swallow_pointer = GetBool(a, "swallowPointer", true);
    const bool allow_move = GetBool(a, "allowMouseMove", false);
    const bool engaged = Lock(swallow_pointer, allow_move);
    result->Success(EncodableValue(engaged));
    return;
  }

  if (method == "unlock") {
    const std::string reason = GetString(a, "reason", "programmatic");
    const bool released = Unlock(reason);
    result->Success(EncodableValue(released));
    return;
  }

  if (method == "isLocked") {
    result->Success(EncodableValue(locked_.load()));
    return;
  }

  result->NotImplemented();
}

bool InputLockPlugin::ConfigureUnlockGesture(const std::string& gesture,
                                             int hold_ms,
                                             bool require_key_up_reset) {
  if (gesture == "holdSpace") {
    gesture_ = Gesture::kHoldSpace;
  } else if (gesture == "holdEsc") {
    gesture_ = Gesture::kHoldEsc;
  } else if (gesture == "holdEscOrSpace") {
    gesture_ = Gesture::kHoldEscOrSpace;
  } else {
    return false;
  }
  hold_duration_ms_.store(hold_ms > 0 ? hold_ms : 2500);
  require_key_up_reset_ = require_key_up_reset;
  gesture_configured_ = true;
  return true;
}

bool InputLockPlugin::Lock(bool swallow_pointer, bool allow_mouse_move) {
  if (!gesture_configured_) {
    // Contract: configureUnlockGesture MUST precede lock(). Refuse otherwise
    // so we never trap the user with no way out.
    return false;
  }
  if (locked_.load()) {
    // Idempotent: already engaged.
    return true;
  }

  swallow_pointer_.store(swallow_pointer);
  allow_mouse_move_.store(allow_mouse_move);
  hold_start_ms_.store(0);
  unlock_completed_.store(false);
  last_emitted_progress_ = -1.0;

  if (!InstallHooks(swallow_pointer)) {
    RemoveHooks();
    EmitLockReleased("error", "SetWindowsHookEx failed");
    return false;
  }

  locked_.store(true);
  StartHeartbeat();
  EmitLockEngaged(swallow_pointer);
  return true;
}

bool InputLockPlugin::Unlock(const std::string& reason) {
  if (!locked_.load()) return true;  // no-op, safe.
  StopHeartbeat();
  RemoveHooks();
  locked_.store(false);
  hold_start_ms_.store(0);
  EmitLockReleased(reason, "");
  return true;
}

// ----------------------------------------------------------------------------
// Hook install / remove (platform thread)
// ----------------------------------------------------------------------------
bool InputLockPlugin::InstallHooks(bool swallow_pointer) {
  // For in-process LL hooks the module handle is the current module and the
  // thread id is 0 (global). The hook fires on THIS thread (the platform/UI
  // thread), which pumps messages via the runner's WinMain loop.
  HMODULE module = ::GetModuleHandleW(nullptr);
  keyboard_hook_ =
      ::SetWindowsHookExW(WH_KEYBOARD_LL, &InputLockPlugin::KeyboardProc,
                          module, 0);
  if (!keyboard_hook_) return false;

  if (swallow_pointer) {
    mouse_hook_ = ::SetWindowsHookExW(WH_MOUSE_LL, &InputLockPlugin::MouseProc,
                                      module, 0);
    if (!mouse_hook_) {
      // Keyboard installed but mouse failed; treat as failure for a clean
      // all-or-nothing lock when pointer swallowing was requested.
      ::UnhookWindowsHookEx(keyboard_hook_);
      keyboard_hook_ = nullptr;
      return false;
    }
  }
  return true;
}

void InputLockPlugin::RemoveHooks() {
  if (mouse_hook_) {
    ::UnhookWindowsHookEx(mouse_hook_);
    mouse_hook_ = nullptr;
  }
  if (keyboard_hook_) {
    ::UnhookWindowsHookEx(keyboard_hook_);
    keyboard_hook_ = nullptr;
  }
}

// ----------------------------------------------------------------------------
// Hook callbacks (platform thread)
// ----------------------------------------------------------------------------
LRESULT CALLBACK InputLockPlugin::KeyboardProc(int code, WPARAM wparam,
                                               LPARAM lparam) {
  if (code == HC_ACTION && g_instance && g_instance->locked_.load()) {
    const auto* info = reinterpret_cast<const KBDLLHOOKSTRUCT*>(lparam);
    if (g_instance->OnLowLevelKeyboard(wparam, info)) {
      // Returning a non-zero value swallows the event: it is NOT passed to the
      // next hook or the focused window. This blocks Alt+Tab, Alt+F4, the Win
      // key, Ctrl+Esc, F-row, media keys, etc. (Ctrl+Alt+Del / Win+L excepted
      // — see caveats.)
      return 1;
    }
  }
  return ::CallNextHookEx(nullptr, code, wparam, lparam);
}

LRESULT CALLBACK InputLockPlugin::MouseProc(int code, WPARAM wparam,
                                            LPARAM lparam) {
  if (code == HC_ACTION && g_instance && g_instance->locked_.load() &&
      g_instance->swallow_pointer_.load()) {
    const auto* info = reinterpret_cast<const MSLLHOOKSTRUCT*>(lparam);
    if (g_instance->OnLowLevelMouse(wparam, info)) {
      return 1;  // swallow click / wheel / (optionally) move
    }
  }
  return ::CallNextHookEx(nullptr, code, wparam, lparam);
}

bool InputLockPlugin::IsUnlockKey(DWORD vk) const {
  switch (gesture_) {
    case Gesture::kHoldSpace:
      return vk == VK_SPACE;
    case Gesture::kHoldEsc:
      return vk == VK_ESCAPE;
    case Gesture::kHoldEscOrSpace:
      return vk == VK_SPACE || vk == VK_ESCAPE;
  }
  return false;
}

bool InputLockPlugin::OnLowLevelKeyboard(WPARAM message,
                                         const KBDLLHOOKSTRUCT* info) {
  if (!info) return true;
  const DWORD vk = info->vkCode;
  const bool is_down =
      (message == WM_KEYDOWN || message == WM_SYSKEYDOWN);
  const bool is_up = (message == WM_KEYUP || message == WM_SYSKEYUP);

  if (IsUnlockKey(vk)) {
    if (is_down) {
      // First WM_KEYDOWN of a continuous hold starts the clock. Auto-repeat
      // WM_KEYDOWNs keep the existing start time (do not reset).
      if (hold_start_ms_.load() == 0) {
        hold_start_ms_.store(NowMs());
      }
    } else if (is_up && require_key_up_reset_) {
      // Early release: cancel the hold; heartbeat will emit progress 0.
      hold_start_ms_.store(0);
    }
    // Swallow the unlock key just like every other key — Dart must NEVER see
    // it; only the unlockProgress stream conveys the hold.
    return true;
  }

  // Any non-unlock key press cancels an in-progress hold (the user must hold
  // the unlock key cleanly).
  if (is_down) {
    hold_start_ms_.store(0);
  }
  return true;  // swallow everything else
}

bool InputLockPlugin::OnLowLevelMouse(WPARAM message,
                                      const MSLLHOOKSTRUCT* /*info*/) {
  if (message == WM_MOUSEMOVE) {
    // Optionally let the cursor move (e.g. to keep the OS cursor responsive)
    // while still swallowing clicks/wheel.
    return !allow_mouse_move_.load();
  }
  // Swallow buttons, wheel, hwheel, xbuttons.
  return true;
}

// ----------------------------------------------------------------------------
// Heartbeat worker -> posts to platform thread
// ----------------------------------------------------------------------------
void InputLockPlugin::StartHeartbeat() {
  if (heartbeat_run_.load()) return;
  heartbeat_run_.store(true);
  heartbeat_thread_ = std::thread(&InputLockPlugin::HeartbeatLoop, this);
}

void InputLockPlugin::StopHeartbeat() {
  if (!heartbeat_run_.load()) return;
  heartbeat_run_.store(false);
  if (heartbeat_thread_.joinable()) heartbeat_thread_.join();
}

void InputLockPlugin::HeartbeatLoop() {
  // ~60 Hz. Each tick simply nudges the platform thread to recompute and emit
  // progress; ALL Flutter channel access stays on the platform thread.
  while (heartbeat_run_.load()) {
    if (host_window_) {
      ::PostMessageW(host_window_, kWmInputLockTick, 0, 0);
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(16));
  }
}

void InputLockPlugin::OnHeartbeatTick() {
  if (!locked_.load()) return;

  const long long start = hold_start_ms_.load();
  const long long dur = hold_duration_ms_.load();
  double progress = 0.0;
  if (start != 0 && dur > 0) {
    const long long elapsed = Clamp01ToMs(NowMs() - start);
    progress = static_cast<double>(elapsed) / static_cast<double>(dur);
    if (progress > 1.0) progress = 1.0;
  }

  // Throttle: emit on meaningful delta (>= 1%) or at the 0 / 1 boundaries.
  const bool boundary =
      (progress == 0.0 && last_emitted_progress_ != 0.0) ||
      (progress >= 1.0 && last_emitted_progress_ < 1.0);
  const bool delta =
      (last_emitted_progress_ < 0.0) ||
      (std::abs(progress - last_emitted_progress_) >= 0.01);
  if (boundary || delta) {
    EmitUnlockProgress(progress);
    last_emitted_progress_ = progress;
  }

  if (progress >= 1.0 && !unlock_completed_.exchange(true)) {
    // Completed hold -> release via user gesture. This is the ONLY normal exit
    // because the keys themselves are swallowed.
    StopHeartbeat();
    RemoveHooks();
    locked_.store(false);
    hold_start_ms_.store(0);
    EmitLockReleased("userGesture", "");
  }
}

// ----------------------------------------------------------------------------
// Event emission (platform thread only)
// ----------------------------------------------------------------------------
void InputLockPlugin::EmitLockEngaged(bool swallows_pointer) {
  if (!event_sink_) return;
  EncodableMap m;
  m[EncodableValue("type")] = EncodableValue("lockEngaged");
  m[EncodableValue("swallowsPointer")] = EncodableValue(swallows_pointer);
  m[EncodableValue("timestampMs")] = EncodableValue(NowMs());
  event_sink_->Success(EncodableValue(m));
}

void InputLockPlugin::EmitLockReleased(const std::string& reason,
                                       const std::string& detail) {
  if (!event_sink_) return;
  EncodableMap m;
  m[EncodableValue("type")] = EncodableValue("lockReleased");
  m[EncodableValue("reason")] = EncodableValue(reason);
  if (!detail.empty()) m[EncodableValue("detail")] = EncodableValue(detail);
  event_sink_->Success(EncodableValue(m));
}

void InputLockPlugin::EmitUnlockProgress(double value) {
  if (!event_sink_) return;
  const char* gesture_name =
      gesture_ == Gesture::kHoldSpace
          ? "holdSpace"
          : (gesture_ == Gesture::kHoldEsc ? "holdEsc" : "holdEscOrSpace");
  EncodableMap m;
  m[EncodableValue("type")] = EncodableValue("unlockProgress");
  m[EncodableValue("value")] = EncodableValue(value);
  m[EncodableValue("gesture")] = EncodableValue(std::string(gesture_name));
  event_sink_->Success(EncodableValue(m));
}

void InputLockPlugin::EmitPermissionChanged(const std::string& status) {
  if (!event_sink_) return;
  EncodableMap m;
  m[EncodableValue("type")] = EncodableValue("permissionChanged");
  m[EncodableValue("status")] = EncodableValue(status);
  event_sink_->Success(EncodableValue(m));
}
