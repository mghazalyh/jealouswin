import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jealouswin/main.dart';

void main() {
  testWidgets('checklist supports completion, adding, and theme changes', (
    tester,
  ) async {
    await tester.pumpWidget(const JealouswinApp());
    expect(find.text('0 of 3 complete'), findsOneWidget);
    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 complete'), findsOneWidget);

    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Build my first feature');
    await tester.tap(find.byTooltip('Add step'));
    await tester.pumpAndSettle();
    expect(find.text('Build my first feature'), findsOneWidget);
    expect(find.text('1 of 4 complete'), findsOneWidget);

    await tester.tap(find.byTooltip('Add step'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 4 complete'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Use dark theme'));
    await tester.tap(find.byTooltip('Use dark theme'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Use light theme'), findsOneWidget);
    expect(find.text('1 of 4 complete'), findsOneWidget);
  });

  testWidgets('fits a narrow mobile viewport without layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const JealouswinApp());
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'A mobile goal');
    await tester.tap(find.byTooltip('Add step'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('A mobile goal'), findsOneWidget);
  });
}
