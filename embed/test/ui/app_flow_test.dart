import 'package:fishfeed/data/demo_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('demo sign in shows the dashboard with live data', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Mode demo'), findsOneWidget);

    await signInWithDemo(tester);
    expect(find.text('Akuarium Ruang Tamu'), findsOneWidget);
    expect(find.text('Kondisi akuarium'), findsOneWidget);
    expect(find.text('Pakan'), findsOneWidget);
    expect(find.text('Jernih'), findsOneWidget);
    expect(find.text('Beri makan sekarang'), findsOneWidget);
    // 07:00 already passed, 12:00 is disabled, so the next one is 17:00.
    expect(find.text('17:00'), findsWidgets);
  });

  testWidgets('the sign in form is validated', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Masuk'));
    expect(find.text('Masukkan alamat email yang valid.'), findsOneWidget);
    expect(find.text('Kata sandi minimal 6 karakter.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      DemoBackend.demoEmail,
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'salah123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Masuk'));
    expect(find.text('Email atau kata sandi salah.'), findsOneWidget);
  });

  testWidgets('a new account can be created', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, find.widgetWithText(TextButton, 'Daftar'));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'sari@mail.id');
    await tester.enterText(fields.at(1), 'rahasia1');
    await tester.enterText(fields.at(2), 'rahasia2');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Daftar'));
    expect(find.text('Kata sandi tidak sama.'), findsOneWidget);

    await tester.enterText(fields.at(2), 'rahasia1');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Daftar'));
    expect(find.text('Halo, sari'), findsOneWidget);
  });

  testWidgets('feeding waits for the device to confirm', (tester) async {
    await pumpApp(tester);
    await signInWithDemo(tester);

    await tapVisible(tester, find.text('Beri makan sekarang'));
    await tester.tap(find.widgetWithText(FilledButton, 'Beri makan'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Mengirim pakan...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Pakan sudah diberikan!'), findsOneWidget);

    await tester.tap(find.text('Kembali ke beranda'));
    await tester.pumpAndSettle();
    expect(find.text('Beri makan sekarang'), findsOneWidget);
  });

  testWidgets('the schedule can be edited and saved', (tester) async {
    final demo = await pumpApp(tester);
    await signInWithDemo(tester);
    await openTab(tester, 'Jadwal');

    expect(find.text('Waktu pemberian pakan (3)'), findsOneWidget);
    await tester.tap(find.text('Siang 12:00'));
    await tester.pumpAndSettle();
    expect(find.text('Waktu 12:00 sudah ada di jadwal.'), findsOneWidget);
    // Let the message go away so it does not cover the save button.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byTooltip('Hapus 12:00'));
    expect(find.text('Waktu pemberian pakan (2)'), findsOneWidget);
    await tester.tap(find.text('Simpan jadwal'));
    await tester.pumpAndSettle();

    final saved = await demo.loadSchedule(DemoBackend.pairedDemoDevice);
    expect(saved.entries.map((e) => e.time), ['07:00', '17:00']);
    expect(find.text('Simpan jadwal'), findsNothing);
  });

  testWidgets('history can be filtered', (tester) async {
    await pumpApp(tester);
    await signInWithDemo(tester);
    await openTab(tester, 'Riwayat');

    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Pakan manual'), findsOneWidget);
    await tester.tap(find.text('Otomatis'));
    await tester.pumpAndSettle();
    expect(find.text('Pakan manual'), findsNothing);
    expect(find.text('Pakan otomatis'), findsWidgets);
  });

  testWidgets('devices can be paired, renamed and selected', (tester) async {
    await pumpApp(tester);
    await signInWithDemo(tester);
    await openTab(tester, 'Akun');
    await tester.tap(find.text('Kelola perangkat'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'FF-9999');
    await tester.tap(find.text('Pasangkan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tidak ditemukan'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ff-2025');
    await tester.tap(find.text('Pasangkan'));
    await tester.pumpAndSettle();
    expect(find.text('Perangkat terpasang (2)'), findsOneWidget);
    expect(find.text('Kolam Teras'), findsOneWidget);

    await tapVisible(tester, find.byTooltip('Pilihan untuk FF-2025'));
    await tester.tap(find.text('Ganti nama'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Kolam Belakang');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Kolam Belakang'), findsOneWidget);
  });

  testWidgets('signing out returns to the sign in page', (tester) async {
    await pumpApp(tester);
    await signInWithDemo(tester);
    await openTab(tester, 'Akun');
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Coba dengan akun demo'), findsOneWidget);
  });
}
