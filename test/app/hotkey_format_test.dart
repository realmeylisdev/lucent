import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lucent/app/desktop_chrome.dart';

void main() {
  group('formatHotKey / parseHotKey', () {
    test('round-trips a ctrl+alt+l combo deterministically', () {
      const token = 'ctrl+alt+l';
      final hotKey = parseHotKey(token);
      expect(hotKey, isNotNull);
      expect(formatHotKey(hotKey!), token);
    });

    test('emits modifiers in canonical order ctrl,alt,shift,cmd', () {
      // Build from a shuffled token; the inverse normalizes order.
      final hotKey = parseHotKey('shift+cmd+alt+ctrl+a');
      expect(hotKey, isNotNull);
      expect(formatHotKey(hotKey!), 'ctrl+alt+shift+cmd+a');
    });

    test('parse accepts modifier aliases, format canonicalizes them', () {
      final hotKey = parseHotKey('control+opt+win+b');
      expect(hotKey, isNotNull);
      expect(formatHotKey(hotKey!), 'ctrl+alt+cmd+b');
    });

    test('returns null when no a-z key is present (modifiers only)', () {
      final hotKey = HotKey(
        key: PhysicalKeyboardKey.escape,
        modifiers: const [HotKeyModifier.control, HotKeyModifier.shift],
      );
      expect(formatHotKey(hotKey), isNull);
    });

    test('returns null for a non a-z key such as a digit', () {
      final hotKey = HotKey(
        key: PhysicalKeyboardKey.digit1,
        modifiers: const [HotKeyModifier.control],
      );
      expect(formatHotKey(hotKey), isNull);
    });

    test('a single letter with no modifiers round-trips', () {
      final hotKey = parseHotKey('z');
      expect(hotKey, isNotNull);
      expect(formatHotKey(hotKey!), 'z');
    });
  });
}
