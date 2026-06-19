// Lucent — Linux native input lock.
//
// Two backends, selected at lock() time by session type:
//
//   * X11 (XDG_SESSION_TYPE=x11, GDK_IS_X11_DISPLAY): an active grab via
//     XGrabKeyboard + XGrabPointer on our fullscreen window. While grabbed,
//     ALL key/pointer events are delivered to OUR window only and never to
//     other clients or the window manager — this is the practical, app-level
//     "input lock" on X11. We install a GDK event filter (gdk_window_add_filter)
//     so the raw XEvents reach us before GTK; we run the unlock-gesture
//     detector on the key stream and DISCARD the events (return
//     GDK_FILTER_REMOVE) so nothing leaks into the Flutter view either.
//     GrabModeAsync is used for both pointer_mode and keyboard_mode so the
//     server keeps processing/delivering events to us without freezing the
//     device between events (GrabModeSync would require an explicit
//     XAllowEvents replay per event and is the wrong model for a passive
//     swallow-everything lock).
//
//   * Wayland (XDG_SESSION_TYPE=wayland): a global keyboard grab is FORBIDDEN
//     by the Wayland security model — no client may steal all input. The best
//     available primitive is zwp_keyboard_shortcuts_inhibit_manager_v1, which
//     asks the compositor to stop interpreting its OWN shortcuts (Alt-Tab,
//     Super, workspace switches, etc.) for our surface while it is focused, so
//     those keys flow to our app instead of triggering compositor actions.
//     This does NOT swallow input from the rest of the system and the
//     compositor MAY still reserve some bindings (notably Super and its
//     emergency/VT shortcuts). We document this limitation honestly and report
//     permissionStatus 'granted' only when the manager global is present.
//
// Because Wayland gives us the key events through normal GTK key handling (the
// inhibitor just stops the compositor from eating them), the unlock-gesture
// detector also hooks GTK key-press/key-release on the window for the Wayland
// path. On X11 the detector runs from the GDK event filter on the grabbed
// stream. Both feed the same gesture state machine.

#include "input_lock_plugin.h"

#include <gdk/gdk.h>
#include <glib.h>

#include <cstring>

#ifdef GDK_WINDOWING_X11
#include <X11/X.h>
#include <X11/Xlib.h>
#include <gdk/gdkx.h>
#endif

#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#include <wayland-client.h>
#include "keyboard-shortcuts-inhibit-unstable-v1-client-protocol.h"
#endif

static constexpr char kMethodChannel[] =
    "video.divine.lucent/input_lock/methods";
static constexpr char kEventChannel[] =
    "video.divine.lucent/input_lock/events";

// Default hold duration if configureUnlockGesture is not called.
static constexpr int kDefaultHoldMs = 2500;

// keysyms we care about for the unlock gesture (X11 keysyms; Wayland/GDK
// produce the same GDK_KEY_* values, which equal the X keysyms).
static constexpr guint kKeySpace = GDK_KEY_space;     // 0x020
static constexpr guint kKeyEscape = GDK_KEY_Escape;   // 0xff1b

typedef enum {
  GESTURE_HOLD_SPACE,
  GESTURE_HOLD_ESC,
  GESTURE_HOLD_ESC_OR_SPACE,
} UnlockGesture;

typedef enum {
  BACKEND_NONE,
  BACKEND_X11,
  BACKEND_WAYLAND,
} LockBackend;

struct _InputLockPlugin {
  GObject parent_instance;

  FlMethodChannel* method_channel;     // owned
  FlEventChannel* event_channel;       // owned
  GtkWindow* window;                   // weak (held via add_weak_pointer)

  gboolean events_listening;           // Dart has an active stream listener
  gboolean locked;
  LockBackend backend;

  // Gesture configuration.
  UnlockGesture gesture;
  int hold_duration_ms;
  gboolean require_keyup_reset;
  gboolean swallow_pointer;

  // Gesture runtime state.
  gboolean holding;                    // an accepted unlock key is down
  guint held_keysym;                   // which key is currently held
  gint64 hold_start_us;                // monotonic time the hold began
  guint progress_timer_id;             // g_timeout pumping unlockProgress
  double last_progress_emitted;        // throttle

#ifdef GDK_WINDOWING_X11
  Display* x_display;                   // not owned (GDK's display)
  Window x_window;                      // grabbed window
  gboolean x_filter_added;
#endif

#ifdef GDK_WINDOWING_WAYLAND
  struct zwp_keyboard_shortcuts_inhibit_manager_v1* wl_inhibit_manager;
  struct zwp_keyboard_shortcuts_inhibitor_v1* wl_inhibitor;
  gulong wl_key_press_handler;
  gulong wl_key_release_handler;
#endif
};

G_DEFINE_TYPE(InputLockPlugin, input_lock_plugin, G_TYPE_OBJECT)

// ---------------------------------------------------------------------------
// Event emission helpers
// ---------------------------------------------------------------------------

static gint64 now_ms() { return g_get_monotonic_time() / 1000; }

// Sends a Map payload on the EventChannel if Dart is listening.
static void emit_event(InputLockPlugin* self, FlValue* map) {
  if (self->events_listening) {
    fl_event_channel_send(self->event_channel, map, nullptr, nullptr);
  }
  fl_value_unref(map);
}

static void emit_lock_engaged(InputLockPlugin* self) {
  FlValue* m = fl_value_new_map();
  fl_value_set_string_take(m, "type", fl_value_new_string("lockEngaged"));
  fl_value_set_string_take(m, "swallowsPointer",
                           fl_value_new_bool(self->swallow_pointer));
  fl_value_set_string_take(m, "timestampMs", fl_value_new_int(now_ms()));
  emit_event(self, m);
}

static void emit_lock_released(InputLockPlugin* self, const char* reason,
                               const char* detail) {
  FlValue* m = fl_value_new_map();
  fl_value_set_string_take(m, "type", fl_value_new_string("lockReleased"));
  fl_value_set_string_take(m, "reason", fl_value_new_string(reason));
  if (detail != nullptr) {
    fl_value_set_string_take(m, "detail", fl_value_new_string(detail));
  } else {
    fl_value_set_string_take(m, "detail", fl_value_new_null());
  }
  emit_event(self, m);
}

static const char* gesture_name(UnlockGesture g) {
  switch (g) {
    case GESTURE_HOLD_SPACE:
      return "holdSpace";
    case GESTURE_HOLD_ESC:
      return "holdEsc";
    case GESTURE_HOLD_ESC_OR_SPACE:
      return "holdEscOrSpace";
  }
  return "holdSpace";
}

static void emit_unlock_progress(InputLockPlugin* self, double value) {
  FlValue* m = fl_value_new_map();
  fl_value_set_string_take(m, "type", fl_value_new_string("unlockProgress"));
  fl_value_set_string_take(m, "value", fl_value_new_float(value));
  fl_value_set_string_take(m, "gesture",
                           fl_value_new_string(gesture_name(self->gesture)));
  emit_event(self, m);
}

static void emit_permission_changed(InputLockPlugin* self,
                                     const char* status) {
  FlValue* m = fl_value_new_map();
  fl_value_set_string_take(m, "type", fl_value_new_string("permissionChanged"));
  fl_value_set_string_take(m, "status", fl_value_new_string(status));
  emit_event(self, m);
}

// ---------------------------------------------------------------------------
// Gesture state machine (backend-agnostic)
// ---------------------------------------------------------------------------

static gboolean keysym_matches_gesture(InputLockPlugin* self, guint keysym) {
  switch (self->gesture) {
    case GESTURE_HOLD_SPACE:
      return keysym == kKeySpace;
    case GESTURE_HOLD_ESC:
      return keysym == kKeyEscape;
    case GESTURE_HOLD_ESC_OR_SPACE:
      return keysym == kKeySpace || keysym == kKeyEscape;
  }
  return FALSE;
}

static void release_grab(InputLockPlugin* self, const char* reason,
                         const char* detail);

// Pumped at ~60fps while a key is held; computes and emits progress, and
// fires the unlock when the hold completes.
static gboolean progress_tick_cb(gpointer user_data) {
  InputLockPlugin* self = INPUT_LOCK_PLUGIN(user_data);
  if (!self->holding) {
    self->progress_timer_id = 0;
    return G_SOURCE_REMOVE;
  }

  gint64 elapsed_us = g_get_monotonic_time() - self->hold_start_us;
  double value = (double)elapsed_us / 1000.0 / (double)self->hold_duration_ms;
  if (value < 0.0) value = 0.0;
  if (value > 1.0) value = 1.0;

  // Throttle on meaningful delta (~1%).
  if (value >= 1.0 || value - self->last_progress_emitted >= 0.01) {
    self->last_progress_emitted = value;
    emit_unlock_progress(self, value);
  }

  if (value >= 1.0) {
    self->holding = FALSE;
    self->progress_timer_id = 0;
    // Releasing the grab restores input; report it as the user gesture. This
    // is the ONLY normal way out of the lock since keys are swallowed.
    release_grab(self, "userGesture", nullptr);
    return G_SOURCE_REMOVE;
  }
  return G_SOURCE_CONTINUE;
}

static void gesture_on_key_down(InputLockPlugin* self, guint keysym) {
  if (!self->locked) return;
  if (!keysym_matches_gesture(self, keysym)) {
    // A non-gesture key while holding does not reset, but a fresh non-gesture
    // key never starts a hold. (X11 auto-repeat re-sends key-down for the held
    // key; we ignore repeats because `holding` is already TRUE.)
    return;
  }
  if (self->holding) return;  // ignore auto-repeat / already counting

  self->holding = TRUE;
  self->held_keysym = keysym;
  self->hold_start_us = g_get_monotonic_time();
  self->last_progress_emitted = -1.0;  // force first emit
  emit_unlock_progress(self, 0.0);
  if (self->progress_timer_id == 0) {
    // ~60fps.
    self->progress_timer_id = g_timeout_add(16, progress_tick_cb, self);
  }
}

static void gesture_on_key_up(InputLockPlugin* self, guint keysym) {
  if (!self->locked || !self->holding) return;
  if (!keysym_matches_gesture(self, keysym)) return;
  if (self->require_keyup_reset && keysym != self->held_keysym) return;

  // Early key-up before completion: reset progress to 0.
  self->holding = FALSE;
  if (self->progress_timer_id != 0) {
    g_source_remove(self->progress_timer_id);
    self->progress_timer_id = 0;
  }
  self->last_progress_emitted = 0.0;
  emit_unlock_progress(self, 0.0);
}

// ---------------------------------------------------------------------------
// X11 backend
// ---------------------------------------------------------------------------

#ifdef GDK_WINDOWING_X11

// GDK event filter: sees raw XEvents on the grabbed display before GTK. We run
// the gesture detector and REMOVE key/button/motion events so they never reach
// the Flutter view (or anything else). Returning GDK_FILTER_REMOVE is how we
// "discard" the events.
static GdkFilterReturn x11_event_filter(GdkXEvent* gdk_xevent,
                                        GdkEvent* /*event*/,
                                        gpointer user_data) {
  InputLockPlugin* self = INPUT_LOCK_PLUGIN(user_data);
  if (!self->locked || self->backend != BACKEND_X11) {
    return GDK_FILTER_CONTINUE;
  }
  XEvent* xev = static_cast<XEvent*>(gdk_xevent);

  switch (xev->type) {
    case KeyPress: {
      KeySym ks = XLookupKeysym(&xev->xkey, 0);
      gesture_on_key_down(self, (guint)ks);
      return GDK_FILTER_REMOVE;  // swallow
    }
    case KeyRelease: {
      KeySym ks = XLookupKeysym(&xev->xkey, 0);
      gesture_on_key_up(self, (guint)ks);
      return GDK_FILTER_REMOVE;  // swallow
    }
    case ButtonPress:
    case ButtonRelease:
    case MotionNotify:
      if (self->swallow_pointer) {
        return GDK_FILTER_REMOVE;  // swallow pointer
      }
      return GDK_FILTER_CONTINUE;
    default:
      return GDK_FILTER_CONTINUE;
  }
}

static gboolean x11_install_grab(InputLockPlugin* self) {
  GdkWindow* gw = gtk_widget_get_window(GTK_WIDGET(self->window));
  if (gw == nullptr) return FALSE;

  GdkDisplay* gdisplay = gdk_window_get_display(gw);
  self->x_display = GDK_DISPLAY_XDISPLAY(gdisplay);
  self->x_window = GDK_WINDOW_XID(gw);

  // Keyboard grab: redirect ALL key events to our window. GrabModeAsync keeps
  // the keyboard "thawed" so the server keeps delivering events without us
  // having to XAllowEvents-replay each one.
  int kbd = XGrabKeyboard(self->x_display, self->x_window,
                          /*owner_events=*/True, GrabModeAsync, GrabModeAsync,
                          CurrentTime);
  if (kbd != GrabSuccess) {
    g_warning("Lucent: XGrabKeyboard failed (code %d)", kbd);
    return FALSE;
  }

  if (self->swallow_pointer) {
    unsigned int mask = ButtonPressMask | ButtonReleaseMask |
                        PointerMotionMask | EnterWindowMask | LeaveWindowMask;
    int ptr = XGrabPointer(self->x_display, self->x_window,
                           /*owner_events=*/True, mask, GrabModeAsync,
                           GrabModeAsync, /*confine_to=*/self->x_window,
                           /*cursor=*/None, CurrentTime);
    if (ptr != GrabSuccess) {
      g_warning("Lucent: XGrabPointer failed (code %d); keyboard-only lock",
                ptr);
      // Keep the keyboard grab; downgrade pointer swallow.
      self->swallow_pointer = FALSE;
    }
  }

  // Add the raw-event filter on our window so we see and discard events.
  gdk_window_add_filter(gw, x11_event_filter, self);
  self->x_filter_added = TRUE;

  XFlush(self->x_display);
  self->backend = BACKEND_X11;
  return TRUE;
}

static void x11_remove_grab(InputLockPlugin* self) {
  if (self->x_display == nullptr) return;
  XUngrabKeyboard(self->x_display, CurrentTime);
  XUngrabPointer(self->x_display, CurrentTime);
  XFlush(self->x_display);

  if (self->x_filter_added) {
    GdkWindow* gw = gtk_widget_get_window(GTK_WIDGET(self->window));
    if (gw != nullptr) {
      gdk_window_remove_filter(gw, x11_event_filter, self);
    }
    self->x_filter_added = FALSE;
  }
  self->x_display = nullptr;
}

#endif  // GDK_WINDOWING_X11

// ---------------------------------------------------------------------------
// Wayland backend
// ---------------------------------------------------------------------------

#ifdef GDK_WINDOWING_WAYLAND

// Registry listener: find the shortcuts-inhibit manager global.
static void wl_registry_global(void* data, struct wl_registry* registry,
                               uint32_t name, const char* interface,
                               uint32_t version) {
  InputLockPlugin* self = INPUT_LOCK_PLUGIN(data);
  if (strcmp(interface,
             zwp_keyboard_shortcuts_inhibit_manager_v1_interface.name) == 0) {
    self->wl_inhibit_manager =
        static_cast<struct zwp_keyboard_shortcuts_inhibit_manager_v1*>(
            wl_registry_bind(
                registry, name,
                &zwp_keyboard_shortcuts_inhibit_manager_v1_interface,
                version < 1 ? version : 1));
  }
}

static void wl_registry_global_remove(void* /*data*/,
                                      struct wl_registry* /*registry*/,
                                      uint32_t /*name*/) {}

static const struct wl_registry_listener kWlRegistryListener = {
    wl_registry_global,
    wl_registry_global_remove,
};

// Lazily bind the manager from the GDK Wayland display's registry. Returns
// TRUE if the compositor advertises the protocol.
static gboolean wl_ensure_manager(InputLockPlugin* self) {
  if (self->wl_inhibit_manager != nullptr) return TRUE;

  GdkDisplay* gdisplay = gdk_display_get_default();
  if (!GDK_IS_WAYLAND_DISPLAY(gdisplay)) return FALSE;

  struct wl_display* display =
      gdk_wayland_display_get_wl_display(gdisplay);
  struct wl_registry* registry = wl_display_get_registry(display);
  wl_registry_add_listener(registry, &kWlRegistryListener, self);
  // Round-trip so the global advertisement + our bind complete.
  wl_display_roundtrip(display);
  wl_registry_destroy(registry);
  return self->wl_inhibit_manager != nullptr;
}

// GTK key handlers feed the gesture detector on Wayland. The inhibitor stops
// the compositor from acting on these keys; GTK still delivers them to us.
static gboolean wl_key_press_cb(GtkWidget* /*w*/, GdkEventKey* ev,
                                gpointer user_data) {
  InputLockPlugin* self = INPUT_LOCK_PLUGIN(user_data);
  if (self->locked && self->backend == BACKEND_WAYLAND) {
    gesture_on_key_down(self, ev->keyval);
    return TRUE;  // consume so it does not propagate to the Flutter view
  }
  return FALSE;
}

static gboolean wl_key_release_cb(GtkWidget* /*w*/, GdkEventKey* ev,
                                  gpointer user_data) {
  InputLockPlugin* self = INPUT_LOCK_PLUGIN(user_data);
  if (self->locked && self->backend == BACKEND_WAYLAND) {
    gesture_on_key_up(self, ev->keyval);
    return TRUE;
  }
  return FALSE;
}

static gboolean wl_install_inhibitor(InputLockPlugin* self) {
  if (!wl_ensure_manager(self)) {
    g_warning(
        "Lucent: compositor does not support "
        "zwp_keyboard_shortcuts_inhibit_manager_v1; cannot inhibit shortcuts");
    return FALSE;
  }

  GdkWindow* gw = gtk_widget_get_window(GTK_WIDGET(self->window));
  if (gw == nullptr || !GDK_IS_WAYLAND_WINDOW(gw)) return FALSE;

  GdkDisplay* gdisplay = gdk_window_get_display(gw);
  struct wl_seat* seat =
      gdk_wayland_device_get_wl_seat(gdk_seat_get_pointer(
          gdk_display_get_default_seat(gdisplay)));
  struct wl_surface* surface = gdk_wayland_window_get_wl_surface(gw);
  if (seat == nullptr || surface == nullptr) return FALSE;

  self->wl_inhibitor =
      zwp_keyboard_shortcuts_inhibit_manager_v1_inhibit_shortcuts(
          self->wl_inhibit_manager, surface, seat);
  if (self->wl_inhibitor == nullptr) return FALSE;

  // Hook GTK key events for the gesture detector.
  self->wl_key_press_handler =
      g_signal_connect(self->window, "key-press-event",
                       G_CALLBACK(wl_key_press_cb), self);
  self->wl_key_release_handler =
      g_signal_connect(self->window, "key-release-event",
                       G_CALLBACK(wl_key_release_cb), self);

  struct wl_display* display =
      gdk_wayland_display_get_wl_display(gdisplay);
  wl_display_flush(display);

  self->backend = BACKEND_WAYLAND;
  return TRUE;
}

static void wl_remove_inhibitor(InputLockPlugin* self) {
  if (self->wl_key_press_handler != 0) {
    g_signal_handler_disconnect(self->window, self->wl_key_press_handler);
    self->wl_key_press_handler = 0;
  }
  if (self->wl_key_release_handler != 0) {
    g_signal_handler_disconnect(self->window, self->wl_key_release_handler);
    self->wl_key_release_handler = 0;
  }
  if (self->wl_inhibitor != nullptr) {
    zwp_keyboard_shortcuts_inhibitor_v1_destroy(self->wl_inhibitor);
    self->wl_inhibitor = nullptr;
  }
  GdkDisplay* gdisplay = gdk_display_get_default();
  if (GDK_IS_WAYLAND_DISPLAY(gdisplay)) {
    wl_display_flush(gdk_wayland_display_get_wl_display(gdisplay));
  }
}

#endif  // GDK_WINDOWING_WAYLAND

// ---------------------------------------------------------------------------
// Session detection & permission
// ---------------------------------------------------------------------------

static gboolean session_is_wayland() {
  GdkDisplay* d = gdk_display_get_default();
#ifdef GDK_WINDOWING_WAYLAND
  if (GDK_IS_WAYLAND_DISPLAY(d)) return TRUE;
#endif
  const char* st = g_getenv("XDG_SESSION_TYPE");
  if (st != nullptr && g_ascii_strcasecmp(st, "wayland") == 0) return TRUE;
  return FALSE;
}

static gboolean session_is_x11() {
  GdkDisplay* d = gdk_display_get_default();
#ifdef GDK_WINDOWING_X11
  if (GDK_IS_X11_DISPLAY(d)) return TRUE;
#endif
  const char* st = g_getenv("XDG_SESSION_TYPE");
  if (st != nullptr && g_ascii_strcasecmp(st, "x11") == 0) return TRUE;
  return FALSE;
}

// permissionStatus per the channel contract:
//   X11        -> 'granted'      (grabs require no special OS permission)
//   Wayland    -> 'granted' if the inhibit manager global exists, else 'denied'
//   otherwise  -> 'notRequired'
static const char* compute_permission_status(InputLockPlugin* self) {
  if (session_is_x11()) {
    return "granted";
  }
  if (session_is_wayland()) {
#ifdef GDK_WINDOWING_WAYLAND
    if (wl_ensure_manager(self)) return "granted";
    return "denied";
#else
    return "denied";
#endif
  }
  return "notRequired";
}

// ---------------------------------------------------------------------------
// lock / unlock orchestration
// ---------------------------------------------------------------------------

static gboolean engage_lock(InputLockPlugin* self) {
  if (self->locked) return TRUE;  // idempotent

  gboolean ok = FALSE;
  if (session_is_wayland()) {
#ifdef GDK_WINDOWING_WAYLAND
    ok = wl_install_inhibitor(self);
#endif
  } else if (session_is_x11()) {
#ifdef GDK_WINDOWING_X11
    ok = x11_install_grab(self);
#endif
  }

  if (!ok) {
    self->backend = BACKEND_NONE;
    return FALSE;
  }

  self->locked = TRUE;
  self->holding = FALSE;
  self->last_progress_emitted = 0.0;
  emit_lock_engaged(self);
  return TRUE;
}

static void release_grab(InputLockPlugin* self, const char* reason,
                         const char* detail) {
  if (!self->locked) {
    return;  // no-op when not locked
  }
  if (self->progress_timer_id != 0) {
    g_source_remove(self->progress_timer_id);
    self->progress_timer_id = 0;
  }
  self->holding = FALSE;

  switch (self->backend) {
#ifdef GDK_WINDOWING_X11
    case BACKEND_X11:
      x11_remove_grab(self);
      break;
#endif
#ifdef GDK_WINDOWING_WAYLAND
    case BACKEND_WAYLAND:
      wl_remove_inhibitor(self);
      break;
#endif
    default:
      break;
  }

  self->locked = FALSE;
  self->backend = BACKEND_NONE;
  emit_lock_released(self, reason, detail);
}

// ---------------------------------------------------------------------------
// MethodChannel handler
// ---------------------------------------------------------------------------

static UnlockGesture parse_gesture(const char* s) {
  if (s != nullptr) {
    if (strcmp(s, "holdEsc") == 0) return GESTURE_HOLD_ESC;
    if (strcmp(s, "holdEscOrSpace") == 0) return GESTURE_HOLD_ESC_OR_SPACE;
  }
  return GESTURE_HOLD_SPACE;
}

static FlValue* arg_lookup(FlValue* args, const char* key) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  return fl_value_lookup_string(args, key);
}

static gboolean arg_bool(FlValue* args, const char* key, gboolean fallback) {
  FlValue* v = arg_lookup(args, key);
  if (v != nullptr && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
    return fl_value_get_bool(v);
  }
  return fallback;
}

static int arg_int(FlValue* args, const char* key, int fallback) {
  FlValue* v = arg_lookup(args, key);
  if (v != nullptr && fl_value_get_type(v) == FL_VALUE_TYPE_INT) {
    return (int)fl_value_get_int(v);
  }
  return fallback;
}

static void method_call_cb(FlMethodChannel* /*channel*/,
                           FlMethodCall* method_call, gpointer user_data) {
  InputLockPlugin* self = INPUT_LOCK_PLUGIN(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "checkPermission") == 0) {
    const char* status = compute_permission_status(self);
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_string(status)));
    // Also broadcast so OnboardingCubit stays in sync.
    emit_permission_changed(self, status);

  } else if (strcmp(method, "requestPermission") == 0) {
    // Linux has no out-of-process permission prompt. Re-evaluate and report.
    const char* status = compute_permission_status(self);
    emit_permission_changed(self, status);
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_string(status)));

  } else if (strcmp(method, "configureUnlockGesture") == 0) {
    FlValue* gv = arg_lookup(args, "gesture");
    const char* gs =
        (gv != nullptr && fl_value_get_type(gv) == FL_VALUE_TYPE_STRING)
            ? fl_value_get_string(gv)
            : nullptr;
    self->gesture = parse_gesture(gs);
    self->hold_duration_ms = arg_int(args, "holdDurationMs", kDefaultHoldMs);
    if (self->hold_duration_ms <= 0) self->hold_duration_ms = kDefaultHoldMs;
    self->require_keyup_reset = arg_bool(args, "requireKeyUpReset", TRUE);
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(TRUE)));

  } else if (strcmp(method, "lock") == 0) {
    self->swallow_pointer = arg_bool(args, "swallowPointer", TRUE);
    gboolean engaged = engage_lock(self);
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(engaged)));

  } else if (strcmp(method, "unlock") == 0) {
    FlValue* rv = arg_lookup(args, "reason");
    const char* reason =
        (rv != nullptr && fl_value_get_type(rv) == FL_VALUE_TYPE_STRING)
            ? fl_value_get_string(rv)
            : "programmatic";
    gboolean was_locked = self->locked;
    // Map a programmatic unlock onto the lockReleased contract. Any explicit
    // reason from Dart is forwarded verbatim.
    release_grab(self, reason, nullptr);
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(was_locked)));

  } else if (strcmp(method, "isLocked") == 0) {
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(self->locked)));

  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

// ---------------------------------------------------------------------------
// EventChannel stream handlers
// ---------------------------------------------------------------------------

static FlMethodErrorResponse* stream_listen_cb(FlEventChannel* /*channel*/,
                                               FlValue* /*args*/,
                                               gpointer user_data) {
  InputLockPlugin* self = INPUT_LOCK_PLUGIN(user_data);
  self->events_listening = TRUE;
  return nullptr;
}

static FlMethodErrorResponse* stream_cancel_cb(FlEventChannel* /*channel*/,
                                               FlValue* /*args*/,
                                               gpointer user_data) {
  InputLockPlugin* self = INPUT_LOCK_PLUGIN(user_data);
  self->events_listening = FALSE;
  return nullptr;
}

// ---------------------------------------------------------------------------
// GObject lifecycle
// ---------------------------------------------------------------------------

static void input_lock_plugin_dispose(GObject* object) {
  InputLockPlugin* self = INPUT_LOCK_PLUGIN(object);

  if (self->locked) {
    release_grab(self, "programmatic", "plugin disposed");
  }
  if (self->progress_timer_id != 0) {
    g_source_remove(self->progress_timer_id);
    self->progress_timer_id = 0;
  }
  if (self->window != nullptr) {
    g_object_remove_weak_pointer(G_OBJECT(self->window),
                                 (gpointer*)&self->window);
    self->window = nullptr;
  }
  g_clear_object(&self->method_channel);
  g_clear_object(&self->event_channel);

  G_OBJECT_CLASS(input_lock_plugin_parent_class)->dispose(object);
}

static void input_lock_plugin_class_init(InputLockPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = input_lock_plugin_dispose;
}

static void input_lock_plugin_init(InputLockPlugin* self) {
  self->gesture = GESTURE_HOLD_SPACE;
  self->hold_duration_ms = kDefaultHoldMs;
  self->require_keyup_reset = TRUE;
  self->swallow_pointer = TRUE;
  self->backend = BACKEND_NONE;
}

InputLockPlugin* input_lock_plugin_new(FlBinaryMessenger* messenger,
                                       GtkWindow* window) {
  InputLockPlugin* self =
      INPUT_LOCK_PLUGIN(g_object_new(INPUT_LOCK_PLUGIN_TYPE, nullptr));

  self->window = window;
  g_object_add_weak_pointer(G_OBJECT(window), (gpointer*)&self->window);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->method_channel =
      fl_method_channel_new(messenger, kMethodChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->method_channel, method_call_cb, g_object_ref(self),
      g_object_unref);

  g_autoptr(FlStandardMethodCodec) event_codec = fl_standard_method_codec_new();
  self->event_channel = fl_event_channel_new(messenger, kEventChannel,
                                             FL_METHOD_CODEC(event_codec));
  fl_event_channel_set_stream_handlers(self->event_channel, stream_listen_cb,
                                       stream_cancel_cb, g_object_ref(self),
                                       g_object_unref);

  return self;
}
