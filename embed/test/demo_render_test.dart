// Rekam layar aplikasi sebagai bingkai PNG untuk GIF demo, tanpa emulator:
// layar digambar di laptop dengan backend demo, lalu disusun menjadi GIF dalam
// bingkai ponsel. Jalankan:
//   DEMO_FRAMES=build/frames flutter test test/demo_render_test.dart
//   python3 tool/render_gif.py build/frames ../docs/images/demo.gif
import 'dart:io';

import 'package:fishfeed/app.dart';
import 'package:fishfeed/data/demo_backend.dart';
import 'package:fishfeed/ui/widgets/feeding_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo/demo_recorder.dart';

void main() {
  final out = Platform.environment['DEMO_FRAMES'];
  testWidgets('bingkai demo', (tester) async {
    await tester.runAsync(
      () => loadFonts({
        for (final family in ['Poppins', 'Inter'])
          family: [
            for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
              'assets/fonts/$family-$w.ttf',
          ],
      }),
    );
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    if (out != null) Directory(out).createSync(recursive: true);
    final now = DateTime(2026, 6, 10, 9, 30);
    final demo = DemoBackend(tickInterval: null, clock: () => now);
    addTearDown(demo.dispose);
    final r = DemoRecorder(tester, out);
    await tester.pumpWidget(
      r.wrap(FishFeedApp(backend: demo, clock: () => now)),
    );

    // 1. pembuka: ikan mendekati pakan yang jatuh dan pakan yang ditabur
    r.scene = 'pembuka';
    await r.run(3800);
    final tank = tester.getRect(find.byType(FeedingLoader));
    await r.tapAt(
      tank.topLeft + Offset(tank.width * .78, tank.height * .3),
      after: 1300,
    );
    await r.tapAt(
      tank.topLeft + Offset(tank.width * .25, tank.height * .35),
      after: 2400,
    );
    await r.run(2400);

    // 2. masuk dengan akun demo
    r.scene = 'masuk';
    await r.run(800);
    await r.tap(find.text('Coba dengan akun demo'), after: 400);
    await r.settle();

    // 3. dasbor: kondisi akuarium, lalu digulir ke grafik
    r.scene = 'dasbor';
    await r.run(1600);
    await r.scroll(-520, steps: 12);
    await r.run(1200);
    await r.scroll(520, steps: 8);
    await r.run(400);

    // 4. beri makan sekarang dan tunggu alat mengonfirmasi
    r.scene = 'beri-makan';
    await r.tap(find.text('Beri makan sekarang'), after: 500);
    await r.tap(find.widgetWithText(FilledButton, 'Beri makan'), after: 0);
    await r.run(3800);
    await r.tap(find.text('Kembali ke beranda'), after: 600);

    // 5. jadwal dan riwayat
    r.scene = 'jadwal';
    await r.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Jadwal'),
      ),
      after: 1800,
    );
    r.scene = 'riwayat';
    await r.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Riwayat'),
      ),
      after: 1800,
    );
    r.finish();
  }, skip: out == null);
}
