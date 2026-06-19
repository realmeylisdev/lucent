cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# === Lucent: native input-lock dependencies ===
# X11 for XGrabKeyboard/XGrabPointer, xkbcommon for keysym handling, and the
# Wayland client + scanner for the keyboard-shortcuts-inhibit protocol.
find_package(PkgConfig REQUIRED)
pkg_check_modules(X11 REQUIRED IMPORTED_TARGET x11)
pkg_check_modules(XKBCOMMON REQUIRED IMPORTED_TARGET xkbcommon)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)
# wayland-protocols ships the unstable protocol XML; wayland-scanner generates
# the client glue. Both are needed at build time on Wayland-capable distros.
pkg_check_modules(WAYLAND_PROTOCOLS REQUIRED wayland-protocols>=1.18)
pkg_get_variable(WAYLAND_PROTOCOLS_DIR wayland-protocols pkgdatadir)
find_program(WAYLAND_SCANNER_EXECUTABLE NAMES wayland-scanner REQUIRED)

set(INPUT_LOCK_PROTO_XML
  "${WAYLAND_PROTOCOLS_DIR}/unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1.xml")
set(INPUT_LOCK_PROTO_DIR "${CMAKE_CURRENT_BINARY_DIR}/wl-protocols")
file(MAKE_DIRECTORY "${INPUT_LOCK_PROTO_DIR}")
set(INPUT_LOCK_PROTO_HEADER
  "${INPUT_LOCK_PROTO_DIR}/keyboard-shortcuts-inhibit-unstable-v1-client-protocol.h")
set(INPUT_LOCK_PROTO_SOURCE
  "${INPUT_LOCK_PROTO_DIR}/keyboard-shortcuts-inhibit-unstable-v1-protocol.c")

add_custom_command(
  OUTPUT "${INPUT_LOCK_PROTO_HEADER}"
  COMMAND "${WAYLAND_SCANNER_EXECUTABLE}" client-header
          "${INPUT_LOCK_PROTO_XML}" "${INPUT_LOCK_PROTO_HEADER}"
  DEPENDS "${INPUT_LOCK_PROTO_XML}"
  VERBATIM)
add_custom_command(
  OUTPUT "${INPUT_LOCK_PROTO_SOURCE}"
  COMMAND "${WAYLAND_SCANNER_EXECUTABLE}" private-code
          "${INPUT_LOCK_PROTO_XML}" "${INPUT_LOCK_PROTO_SOURCE}"
  DEPENDS "${INPUT_LOCK_PROTO_XML}"
  VERBATIM)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "input_lock_plugin.cc"
  "${INPUT_LOCK_PROTO_SOURCE}"
  "${INPUT_LOCK_PROTO_HEADER}"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# The generated Wayland protocol C is third-party and not warning-clean under
# -Wall -Werror; relax just that file.
set_source_files_properties("${INPUT_LOCK_PROTO_SOURCE}"
  PROPERTIES COMPILE_FLAGS "-Wno-error -w")

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::X11)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::XKBCOMMON)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::WAYLAND_CLIENT)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
# So input_lock_plugin.cc can #include the generated protocol header.
target_include_directories(${BINARY_NAME} PRIVATE "${INPUT_LOCK_PROTO_DIR}")
