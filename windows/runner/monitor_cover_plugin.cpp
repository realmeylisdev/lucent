#include "monitor_cover_plugin.h"

#include <flutter/encodable_value.h>

#include <variant>

using flutter::EncodableMap;
using flutter::EncodableValue;

namespace {

const char kMethodChannelName[] = "video.divine.lucent/monitor_cover";
const wchar_t kCoverWindowClass[] = L"LucentMonitorCoverWindow";

// Pulls a String value out of an EncodableMap argument.
std::string GetString(const EncodableMap& map, const char* key,
                      const std::string& fallback) {
  auto it = map.find(EncodableValue(std::string(key)));
  if (it != map.end() && std::holds_alternative<std::string>(it->second)) {
    return std::get<std::string>(it->second);
  }
  return fallback;
}

}  // namespace

MonitorCoverPlugin::MonitorCoverPlugin(flutter::BinaryMessenger* messenger)
    : messenger_(messenger) {
  method_channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger_, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

MonitorCoverPlugin::~MonitorCoverPlugin() { Shutdown(); }

void MonitorCoverPlugin::Shutdown() {
  Release();
  if (class_registered_) {
    ::UnregisterClassW(kCoverWindowClass, ::GetModuleHandleW(nullptr));
    class_registered_ = false;
  }
}

// ----------------------------------------------------------------------------
// Method dispatch (platform thread)
// ----------------------------------------------------------------------------
void MonitorCoverPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "cover") {
    const auto* args = std::get_if<EncodableMap>(call.arguments());
    EncodableMap empty;
    const EncodableMap& a = args ? *args : empty;
    const std::string hex = GetString(a, "colorHex", "#000000");
    const bool ok = Cover(ParseHexColor(hex));
    result->Success(EncodableValue(ok));
    return;
  }

  if (method == "release") {
    Release();
    result->Success(EncodableValue(true));
    return;
  }

  result->NotImplemented();
}

// ----------------------------------------------------------------------------
// Color parsing
// ----------------------------------------------------------------------------
COLORREF MonitorCoverPlugin::ParseHexColor(const std::string& hex) {
  std::string value = hex;
  if (!value.empty() && value.front() == '#') value.erase(value.begin());
  if (value.size() != 6) return RGB(0, 0, 0);
  unsigned long rgb = 0;
  try {
    size_t consumed = 0;
    rgb = std::stoul(value, &consumed, 16);
    if (consumed != value.size()) return RGB(0, 0, 0);
  } catch (...) {
    return RGB(0, 0, 0);
  }
  const BYTE r = static_cast<BYTE>((rgb >> 16) & 0xFF);
  const BYTE g = static_cast<BYTE>((rgb >> 8) & 0xFF);
  const BYTE b = static_cast<BYTE>(rgb & 0xFF);
  return RGB(r, g, b);
}

// ----------------------------------------------------------------------------
// Monitor enumeration
// ----------------------------------------------------------------------------
BOOL CALLBACK MonitorCoverPlugin::EnumMonitorProc(HMONITOR monitor, HDC /*hdc*/,
                                                  LPRECT /*rect*/,
                                                  LPARAM lparam) {
  auto* covers = reinterpret_cast<MonitorCoverPlugin*>(lparam);
  MONITORINFO info = {};
  info.cbSize = sizeof(MONITORINFO);
  if (!::GetMonitorInfoW(monitor, &info)) return TRUE;  // skip, keep going
  // Cover every NON-primary monitor (mirrors macOS skipping NSScreen.main).
  if ((info.dwFlags & MONITORINFOF_PRIMARY) != 0) return TRUE;

  const RECT& r = info.rcMonitor;
  const int width = r.right - r.left;
  const int height = r.bottom - r.top;
  if (width <= 0 || height <= 0) return TRUE;

  HWND window = ::CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW, kCoverWindowClass,
      L"", WS_POPUP, r.left, r.top, width, height, nullptr, nullptr,
      ::GetModuleHandleW(nullptr), nullptr);
  if (!window) return TRUE;

  // Stash the brush on the window so its WindowProc can paint the background.
  ::SetWindowLongPtrW(window, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(covers->background_brush_));
  ::ShowWindow(window, SW_SHOWNOACTIVATE);
  covers->cover_windows_.push_back(window);
  return TRUE;
}

// ----------------------------------------------------------------------------
// Cover window proc (paints the solid color)
// ----------------------------------------------------------------------------
LRESULT CALLBACK MonitorCoverPlugin::CoverWndProc(HWND hwnd, UINT message,
                                                  WPARAM wparam,
                                                  LPARAM lparam) {
  switch (message) {
    case WM_ERASEBKGND: {
      HBRUSH brush = reinterpret_cast<HBRUSH>(
          ::GetWindowLongPtrW(hwnd, GWLP_USERDATA));
      if (brush) {
        HDC hdc = reinterpret_cast<HDC>(wparam);
        RECT rect;
        ::GetClientRect(hwnd, &rect);
        ::FillRect(hdc, &rect, brush);
        return 1;  // background erased
      }
      break;
    }
    case WM_PAINT: {
      PAINTSTRUCT ps;
      HDC hdc = ::BeginPaint(hwnd, &ps);
      HBRUSH brush = reinterpret_cast<HBRUSH>(
          ::GetWindowLongPtrW(hwnd, GWLP_USERDATA));
      if (brush) {
        ::FillRect(hdc, &ps.rcPaint, brush);
      }
      ::EndPaint(hwnd, &ps);
      return 0;
    }
    // A borderless cover must never steal the foreground / activation.
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
    case WM_NCHITTEST:
      return HTNOWHERE;  // transparent to hit-testing; never grabs the cursor
    default:
      break;
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}

// ----------------------------------------------------------------------------
// Cover / release
// ----------------------------------------------------------------------------
bool MonitorCoverPlugin::Cover(COLORREF color) {
  Release();

  if (!class_registered_) {
    WNDCLASSW wc = {};
    wc.lpfnWndProc = &MonitorCoverPlugin::CoverWndProc;
    wc.hInstance = ::GetModuleHandleW(nullptr);
    wc.lpszClassName = kCoverWindowClass;
    wc.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
    // Background is painted per-window from the stashed brush (WM_ERASEBKGND).
    wc.hbrBackground = nullptr;
    if (!::RegisterClassW(&wc)) {
      // Already registered by a prior instance is fine; any other failure is
      // fatal for covering.
      if (::GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return false;
    }
    class_registered_ = true;
  }

  background_brush_ = ::CreateSolidBrush(color);
  if (!background_brush_) return false;

  ::EnumDisplayMonitors(nullptr, nullptr,
                        &MonitorCoverPlugin::EnumMonitorProc,
                        reinterpret_cast<LPARAM>(this));

  // Success even when there are zero non-primary monitors (nothing to cover),
  // matching the macOS plugin which simply returns true.
  return true;
}

void MonitorCoverPlugin::Release() {
  for (HWND window : cover_windows_) {
    if (window) ::DestroyWindow(window);
  }
  cover_windows_.clear();
  if (background_brush_) {
    ::DeleteObject(background_brush_);
    background_brush_ = nullptr;
  }
}
