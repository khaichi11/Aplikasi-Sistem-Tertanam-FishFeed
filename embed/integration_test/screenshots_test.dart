import 'package:fishfeed/app.dart';
import 'package:fishfeed/data/demo_backend.dart';
import 'package:fishfeed/ui/pages/about_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshots of every screen in demo mode', (tester) async {
    final demo = DemoBackend(tickInterval: null);
    await binding.convertFlutterSurfaceToImage();

    Future<void> settle([int frames = 10]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shoot(String name) async {
      await settle();
      await binding.takeScreenshot(name);
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await settle(3);
      await tester.tap(finder);
      await settle();
    }

    Future<void> openTab(String label) => tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );

    await tester.pumpWidget(FishFeedApp(backend: demo));
    await shoot('01-login');

    await tap(find.text('Coba dengan akun demo'));
    await shoot('02-dashboard');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await shoot('03-dashboard-chart');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await settle();

    await tap(find.text('Beri makan sekarang'));
    await tap(find.widgetWithText(FilledButton, 'Beri makan'));
    await tester.pump(const Duration(seconds: 3));
    await shoot('04-feed-done');
    await tap(find.text('Kembali ke beranda'));

    await openTab('Jadwal');
    await shoot('05-schedule');

    await openTab('Riwayat');
    await shoot('06-activity');

    await openTab('Akun');
    await tap(find.text('Kelola perangkat'));
    await tester.enterText(find.byType(TextField), DemoBackend.spareDemoDevice);
    await tap(find.text('Pasangkan'));
    await settle(30);
    await shoot('07-devices');

    await tap(find.text('Kolam Teras'));
    await tester.pageBack();
    await settle();
    await openTab('Beranda');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
    await shoot('08-dashboard-alerts');

    await openTab('Akun');
    await shoot('09-account');

    await tap(find.text('Tentang FishFeed'));
    await settle();
    expect(find.byType(AboutPage), findsOneWidget);
    await shoot('10-about');

    demo.dispose();
  });
}
