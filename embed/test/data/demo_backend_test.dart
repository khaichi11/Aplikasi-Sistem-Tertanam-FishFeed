import 'package:fake_async/fake_async.dart';
import 'package:fishfeed/data/demo_backend.dart';
import 'package:fishfeed/data/feeder_backend.dart';
import 'package:fishfeed/models/feed_schedule.dart';
import 'package:fishfeed/state/device_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DemoBackend backend() =>
      DemoBackend(tickInterval: null, clock: () => DateTime(2026, 6, 10, 15));

  test('sign in creates demo accounts and checks known passwords', () async {
    final demo = backend();
    await demo.signIn(email: 'Budi@Mail.com', password: 'rahasia');
    expect(demo.currentUser!.email, 'budi@mail.com');
    await demo.signOut();
    expect(demo.currentUser, isNull);
    await expectLater(
      demo.signIn(email: DemoBackend.demoEmail, password: 'wrong'),
      throwsA(isA<BackendException>()),
    );
    await expectLater(
      demo.signUp(email: 'budi@mail.com', password: 'x12345'),
      throwsA(isA<BackendException>()),
    );
    demo.dispose();
  });

  test('a feed command is logged and confirmed by the simulated device', () {
    fakeAsync((async) {
      final demo = DemoBackend(
        tickInterval: null,
        clock: () => DateTime(2026, 6, 10, 15),
      );
      final statuses = <CommandStatus>[];
      demo.watchCommandStatus('FF-2024').listen(statuses.add);
      final activity = <int>[];
      demo.watchActivity('FF-2024').listen((list) => activity.add(list.length));
      async.flushMicrotasks();
      final before = activity.last;

      demo.sendFeedCommand(deviceId: 'FF-2024', uid: 'u');
      async.flushMicrotasks();
      expect(statuses.last, CommandStatus.pending);
      expect(activity.last, before + 1);

      async.elapse(const Duration(seconds: 3));
      expect(statuses.last, CommandStatus.done);
      demo.dispose();
    });
  });

  test('saving a schedule replaces it and is logged', () async {
    final demo = backend();
    const schedule = FeedSchedule(
      active: true,
      entries: [ScheduleEntry(id: 'n', time: '20:00')],
    );
    await demo.saveSchedule('FF-2024', schedule);
    expect((await demo.loadSchedule('FF-2024')).entries.single.time, '20:00');
    final latest = await demo.watchActivity('FF-2024').first;
    expect(latest.first.type, 'schedule_update');
    demo.dispose();
  });

  group('DeviceController', () {
    late DemoBackend demo;
    late DeviceController controller;

    setUp(() async {
      demo = backend();
      await demo.signIn(email: DemoBackend.demoEmail, password: 'demo123');
      controller = DeviceController(backend: demo, user: demo.currentUser!);
      await controller.load();
    });

    tearDown(() => demo.dispose());

    test('loads the paired device and its schedule', () {
      expect(controller.devices, [DemoBackend.pairedDemoDevice]);
      expect(controller.selectedId, DemoBackend.pairedDemoDevice);
      expect(controller.schedule.entries, hasLength(3));
    });

    test('pairing validates the ID', () async {
      await expectLater(controller.pair(' '), throwsA(isA<BackendException>()));
      await expectLater(
        controller.pair('ff-2024'),
        throwsA(isA<BackendException>()),
      );
      await expectLater(
        controller.pair('FF-9999'),
        throwsA(isA<BackendException>()),
      );
      await controller.pair(' ff-2025 ');
      expect(controller.devices, ['FF-2024', 'FF-2025']);
    });

    test('unpairing the selected device selects another one', () async {
      await controller.pair('FF-2025');
      await controller.unpair('FF-2024');
      expect(controller.selectedId, 'FF-2025');
      await controller.unpair('FF-2025');
      expect(controller.hasDevice, isFalse);
      expect(controller.schedule.entries, isEmpty);
    });

    test('renaming needs a name', () async {
      await expectLater(
        controller.rename('FF-2024', '  '),
        throwsA(isA<BackendException>()),
      );
      await controller.rename('FF-2024', 'Akuarium Kamar');
      final device = await demo.watchDevice('FF-2024').first;
      expect(device.name, 'Akuarium Kamar');
    });
  });
}
