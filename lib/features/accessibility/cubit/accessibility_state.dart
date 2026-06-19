part of 'accessibility_cubit.dart';

enum AccessibilityStatus { unknown, granted, denied }

class AccessibilityState extends Equatable {
  const AccessibilityState({required this.status});

  const AccessibilityState.unknown() : status = AccessibilityStatus.unknown;

  final AccessibilityStatus status;

  bool get isGranted => status == AccessibilityStatus.granted;
  bool get needsGrant => status == AccessibilityStatus.denied;

  @override
  List<Object?> get props => [status];
}
