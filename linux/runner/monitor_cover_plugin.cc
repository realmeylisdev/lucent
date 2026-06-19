// Lucent — Linux native secondary-display blackout.
//
// Mirrors the macOS MonitorCoverPlugin: on "cover" it iterates the GDK
// monitors of the default display, skips the primary one, and for each
// remaining monitor spawns a borderless, keep-above GtkWindow filling that
// monitor's geometry painted a solid parsed-hex color. On "release" it
// destroys every cover window.
//
// Positioning notes:
//   * X11: gtk_window_move + gtk_window_resize place each cover precisely over
//     its monitor. This is the fully-working path.
//   * Wayland: the security model forbids clients from positioning their own
//     toplevels at absolute coordinates, so gtk_window_move is advisory and may
//     be ignored by the compositor. We still create one borderless keep-above
//     window per non-primary monitor and size it to the monitor geometry, but
//     where it actually lands is up to the compositor. We never crash on
//     Wayland — we degrade. (See caveats.)
//
// Primary-monitor identification:
//   * Prefer gdk_display_get_primary_monitor(); on Wayland this is frequently
//     NULL.
//   * If NULL, fall back to the monitor that contains the app's top-level
//     window; failing that, fall back to monitor index 0. Either way at least
//     one monitor is treated as "primary" so we never blanket the only/primary
//     screen with a cover.

#include "monitor_cover_plugin.h"

#include <gdk/gdk.h>

#include <cstdint>
#include <cstring>
#include <vector>

static constexpr char kChannel[] = "video.divine.lucent/monitor_cover";

struct _MonitorCoverPlugin {
  GObject parent_instance;

  FlMethodChannel* method_channel;  // owned
  GtkWindow* window;                // weak (held via add_weak_pointer)

  // Live cover windows (one per non-primary monitor). Heap-allocated so we can
  // store it in a GObject-style struct.
  std::vector<GtkWidget*>* covers;
};

G_DEFINE_TYPE(MonitorCoverPlugin, monitor_cover_plugin, G_TYPE_OBJECT)

// ---------------------------------------------------------------------------
// Color parsing
// ---------------------------------------------------------------------------

// Parses "#rrggbb" (also tolerates "rrggbb" and a leading/trailing whitespace)
// into a GdkRGBA. Falls back to opaque black on any malformed input. Always
// sets alpha to 1.0 (an opaque, solid cover).
static void parse_hex_color(const char* hex, GdkRGBA* out) {
  out->red = 0.0;
  out->green = 0.0;
  out->blue = 0.0;
  out->alpha = 1.0;
  if (hex == nullptr) return;

  // gdk_rgba_parse accepts "#rrggbb" and named colors. Use it first; if it
  // fails, leave black.
  GdkRGBA parsed;
  if (gdk_rgba_parse(&parsed, hex)) {
    out->red = parsed.red;
    out->green = parsed.green;
    out->blue = parsed.blue;
    out->alpha = 1.0;  // force opaque regardless of any alpha in the string
  }
}

// ---------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------

// Holds the cover color for a single window; freed when the window is
// destroyed. Stored as the user_data of the "draw" handler.
struct CoverColor {
  GdkRGBA rgba;
};

static void cover_color_free(gpointer data, GClosure* /*closure*/) {
  delete static_cast<CoverColor*>(data);
}

// Fills the whole drawing area with the solid cover color.
static gboolean cover_draw_cb(GtkWidget* widget, cairo_t* cr,
                              gpointer user_data) {
  const CoverColor* c = static_cast<const CoverColor*>(user_data);
  GtkAllocation alloc;
  gtk_widget_get_allocation(widget, &alloc);
  cairo_set_source_rgb(cr, c->rgba.red, c->rgba.green, c->rgba.blue);
  cairo_rectangle(cr, 0, 0, alloc.width, alloc.height);
  cairo_fill(cr);
  return TRUE;  // fully handled; do not propagate
}

// ---------------------------------------------------------------------------
// Monitor enumeration helpers
// ---------------------------------------------------------------------------

// Returns the index of the primary monitor on `display`, or -1 if it cannot be
// determined from gdk_display_get_primary_monitor / the app window.
static int primary_monitor_index(MonitorCoverPlugin* self,
                                  GdkDisplay* display) {
  int n = gdk_display_get_n_monitors(display);
  if (n <= 0) return -1;

  GdkMonitor* primary = gdk_display_get_primary_monitor(display);
  if (primary != nullptr) {
    for (int i = 0; i < n; i++) {
      if (gdk_display_get_monitor(display, i) == primary) return i;
    }
  }

  // Fall back to the monitor containing the app's top-level window (common on
  // Wayland where get_primary_monitor returns NULL).
  if (self->window != nullptr) {
    GdkWindow* gw = gtk_widget_get_window(GTK_WIDGET(self->window));
    if (gw != nullptr) {
      GdkMonitor* at = gdk_display_get_monitor_at_window(display, gw);
      if (at != nullptr) {
        for (int i = 0; i < n; i++) {
          if (gdk_display_get_monitor(display, i) == at) return i;
        }
      }
    }
  }

  return -1;
}

// ---------------------------------------------------------------------------
// cover / release
// ---------------------------------------------------------------------------

static void release_covers(MonitorCoverPlugin* self) {
  if (self->covers == nullptr) return;
  for (GtkWidget* w : *self->covers) {
    if (w != nullptr) {
      gtk_widget_destroy(w);
    }
  }
  self->covers->clear();
}

// Builds one borderless keep-above cover window over `monitor` painted `rgba`.
// Returns the new top-level GtkWidget (already shown), or nullptr on failure.
static GtkWidget* make_cover_window(GdkMonitor* monitor, const GdkRGBA* rgba) {
  GdkRectangle geom;
  gdk_monitor_get_geometry(monitor, &geom);

  GtkWidget* win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_decorated(GTK_WINDOW(win), FALSE);
  gtk_window_set_resizable(GTK_WINDOW(win), FALSE);
  gtk_window_set_skip_taskbar_hint(GTK_WINDOW(win), TRUE);
  gtk_window_set_skip_pager_hint(GTK_WINDOW(win), TRUE);
  gtk_window_set_accept_focus(GTK_WINDOW(win), FALSE);
  gtk_window_set_focus_on_map(GTK_WINDOW(win), FALSE);
  // SPLASHSCREEN: borderless, no WM chrome, stays above normal windows.
  gtk_window_set_type_hint(GTK_WINDOW(win), GDK_WINDOW_TYPE_HINT_SPLASHSCREEN);
  gtk_window_set_keep_above(GTK_WINDOW(win), TRUE);

  // A drawing area that fills the window with the solid cover color.
  GtkWidget* area = gtk_drawing_area_new();
  CoverColor* color = new CoverColor();
  color->rgba = *rgba;
  g_signal_connect_data(area, "draw", G_CALLBACK(cover_draw_cb), color,
                        cover_color_free, static_cast<GConnectFlags>(0));
  gtk_container_add(GTK_CONTAINER(win), area);

  // Size to the monitor geometry. On X11 the move lands precisely; on Wayland
  // the move is advisory (compositor may ignore it) but sizing still applies.
  gtk_window_set_default_size(GTK_WINDOW(win), geom.width, geom.height);
  gtk_window_resize(GTK_WINDOW(win), geom.width, geom.height);
  gtk_window_move(GTK_WINDOW(win), geom.x, geom.y);

  gtk_widget_show_all(win);
  // Reassert geometry after realize/map; some WMs clamp before the window is
  // mapped. Harmless on Wayland.
  gtk_window_move(GTK_WINDOW(win), geom.x, geom.y);
  gtk_window_resize(GTK_WINDOW(win), geom.width, geom.height);

  return win;
}

// Spawns a cover over every non-primary monitor. Returns TRUE if at least the
// enumeration succeeded (even if zero covers were needed because there is only
// one monitor); FALSE only if there is no usable display.
static gboolean do_cover(MonitorCoverPlugin* self, const char* color_hex) {
  // Always start from a clean slate so repeated cover() calls don't stack.
  release_covers(self);

  GdkDisplay* display = gdk_display_get_default();
  if (display == nullptr) return FALSE;

  int n = gdk_display_get_n_monitors(display);
  if (n <= 0) return FALSE;

  GdkRGBA rgba;
  parse_hex_color(color_hex, &rgba);

  int primary = primary_monitor_index(self, display);
  // If we truly couldn't identify a primary, default to index 0 so we never
  // blanket the (likely only) primary screen.
  if (primary < 0) primary = 0;

  for (int i = 0; i < n; i++) {
    if (i == primary) continue;  // skip the primary display
    GdkMonitor* monitor = gdk_display_get_monitor(display, i);
    if (monitor == nullptr) continue;
    GtkWidget* win = make_cover_window(monitor, &rgba);
    if (win != nullptr) {
      self->covers->push_back(win);
    }
  }

  return TRUE;
}

// ---------------------------------------------------------------------------
// MethodChannel handler
// ---------------------------------------------------------------------------

static void method_call_cb(FlMethodChannel* /*channel*/,
                           FlMethodCall* method_call, gpointer user_data) {
  MonitorCoverPlugin* self = MONITOR_COVER_PLUGIN(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "cover") == 0) {
    const char* hex = "#000000";
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "colorHex");
      if (v != nullptr && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
        hex = fl_value_get_string(v);
      }
    }
    gboolean ok = do_cover(self, hex);
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(ok)));

  } else if (strcmp(method, "release") == 0) {
    release_covers(self);
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(TRUE)));

  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

// ---------------------------------------------------------------------------
// GObject lifecycle
// ---------------------------------------------------------------------------

static void monitor_cover_plugin_dispose(GObject* object) {
  MonitorCoverPlugin* self = MONITOR_COVER_PLUGIN(object);

  if (self->covers != nullptr) {
    release_covers(self);
    delete self->covers;
    self->covers = nullptr;
  }
  if (self->window != nullptr) {
    g_object_remove_weak_pointer(G_OBJECT(self->window),
                                 (gpointer*)&self->window);
    self->window = nullptr;
  }
  g_clear_object(&self->method_channel);

  G_OBJECT_CLASS(monitor_cover_plugin_parent_class)->dispose(object);
}

static void monitor_cover_plugin_class_init(MonitorCoverPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = monitor_cover_plugin_dispose;
}

static void monitor_cover_plugin_init(MonitorCoverPlugin* self) {
  self->covers = new std::vector<GtkWidget*>();
}

MonitorCoverPlugin* monitor_cover_plugin_new(FlBinaryMessenger* messenger,
                                             GtkWindow* window) {
  MonitorCoverPlugin* self =
      MONITOR_COVER_PLUGIN(g_object_new(MONITOR_COVER_PLUGIN_TYPE, nullptr));

  self->window = window;
  g_object_add_weak_pointer(G_OBJECT(window), (gpointer*)&self->window);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->method_channel =
      fl_method_channel_new(messenger, kChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->method_channel, method_call_cb, g_object_ref(self),
      g_object_unref);

  return self;
}
