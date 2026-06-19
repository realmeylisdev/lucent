#ifndef RUNNER_MONITOR_COVER_PLUGIN_H_
#define RUNNER_MONITOR_COVER_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS

// MonitorCoverPlugin implements the "video.divine.lucent/monitor_cover"
// MethodChannel for the Linux runner. It mirrors the macOS MonitorCoverPlugin:
// on "cover" it spawns a borderless, keep-above, solid-color GtkWindow over
// every NON-primary monitor (the visual blackout of secondary screens during a
// cleaning session); on "release" it destroys all of them.
//
// Methods:
//   * "cover"   { colorHex: String like "#rrggbb" } -> bool
//   * "release"                                      -> bool
//
// On X11 the cover windows are positioned per-monitor via gtk_window_move. On
// Wayland absolute window positioning is restricted by the security model, so
// per-monitor placement is best-effort and may be ignored by the compositor;
// the plugin degrades gracefully and never crashes there.

#define MONITOR_COVER_PLUGIN_TYPE (monitor_cover_plugin_get_type())

G_DECLARE_FINAL_TYPE(MonitorCoverPlugin,
                     monitor_cover_plugin,
                     MONITOR_COVER,
                     PLUGIN,
                     GObject)

// Creates the plugin and registers the channel on `messenger`. `window` is the
// top-level GtkWindow hosting the FlView; it is used only to identify the
// monitor the app lives on when no primary monitor is reported (e.g. Wayland).
// The plugin keeps a weak reference to `window`.
//
// Ownership: the returned plugin is owned by the caller (MyApplication, which
// keeps it alive for the lifetime of the window).
MonitorCoverPlugin* monitor_cover_plugin_new(FlBinaryMessenger* messenger,
                                             GtkWindow* window);

G_END_DECLS

#endif  // RUNNER_MONITOR_COVER_PLUGIN_H_
