import 'package:fishfeed/app.dart';
import 'package:fishfeed/data/demo_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final testNow = DateTime(2026, 6, 10, 9, 30);

DemoBackend demoBackend() =>
    DemoBackend(tickInterval: null, clock: () => testNow);

/// Pumps the app at phone size with animations reduced.
Future<DemoBackend> pumpApp(WidgetTester tester, {DemoBackend? backend}) async {
  final demo = backend ?? demoBackend();
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  addTearDown(demo.dispose);
  await tester.pumpWidget(
    FishFeedApp(backend: demo, clock: () => testNow, intro: false),
  );
  await tester.pump();
  return demo;
}

/// Scrolls [finder] into view, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.dragUntilVisible(
      finder,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> signInWithDemo(WidgetTester tester) =>
    tapVisible(tester, find.text('Coba dengan akun demo'));

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}
