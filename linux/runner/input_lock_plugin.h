#ifndef RUNNER_INPUT_LOCK_PLUGIN_H_
#define RUNNER_INPUT_LOCK_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS

// InputLockPlugin implements the
// "video.divine.lucent/input_lock/methods" MethodChannel and the
// "video.divine.lucent/input_lock/events" EventChannel for the Linux runner.
//
// It owns the platform-specific input grab (X11 XGrabKeyboard/XGrabPointer or
// the Wayland zwp_keyboard_shortcuts_inhibit_manager_v1 protocol) and the
// hold-to-unlock gesture detector. Because the grab swallows the unlock key,
// Dart never sees it: the plugin detects the hold internally and streams
// `unlockProgress` followed by `lockReleased(reason:'userGesture')`.

#define INPUT_LOCK_PLUGIN_TYPE (input_lock_plugin_get_type())

G_DECLARE_FINAL_TYPE(InputLockPlugin,
                     input_lock_plugin,
                     INPUT_LOCK,
                     PLUGIN,
                     GObject)

// Creates the plugin, registers both channels on `messenger`, and binds the
// grab to `window` (the top-level GtkWindow hosting the FlView). The plugin
// keeps a weak reference to `window`.
//
// Ownership: the returned plugin is owned by the caller (typically
// MyApplication, which keeps it alive for the lifetime of the window).
InputLockPlugin* input_lock_plugin_new(FlBinaryMessenger* messenger,
                                       GtkWindow* window);

G_END_DECLS

#endif  // RUNNER_INPUT_LOCK_PLUGIN_H_
