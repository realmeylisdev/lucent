import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/core/platform/native_lock_controller.dart';

part 'accessibility_state.dart';

/// Tracks macOS Accessibility / Input-Monitoring trust (AXIsProcessTrusted).
///
/// On non-macOS platforms the native lock needs no such grant, so the cubit
/// reports [AccessibilityStatus.granted] immediately.
class AccessibilityCubit extends Cubit<AccessibilityState> {
  AccessibilityCubit({required this._nativeLock})
      : super(const AccessibilityState.unknown());

  final NativeLockController _nativeLock;

  bool get _isMacOS => Platform.isMacOS;

  /// Re-query the OS for the current permission state.
  Future<void> refresh() async {
    if (!_isMacOS) {
      emit(const AccessibilityState(status: AccessibilityStatus.granted));
      return;
    }
    final trusted = await _nativeLock.isAccessibilityTrusted();
    emit(
      AccessibilityState(
        status: trusted
            ? AccessibilityStatus.granted
            : AccessibilityStatus.denied,
      ),
    );
  }

  /// Open System Settings so the user can grant the permission.
  Future<void> openSettings() => _nativeLock.openAccessibilitySettings();
}
