import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/features/about/view/about_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Lucent',
      packageName: 'video.divine.lucent',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('renders the name, version, GitHub link and license', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    await tester.pumpAndSettle();

    expect(find.text('Lucent'), findsOneWidget);
    expect(find.text('Version 1.0.0+1'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'View on GitHub'),
      findsOneWidget,
    );
    expect(find.text('MIT License'), findsOneWidget);
  });
}
