import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/feeder_backend.dart';
import '../../models/activity_entry.dart';
import '../../models/device_snapshot.dart';

/// Mendengarkan data langsung satu perangkat. Aliran dibuat ulang hanya saat
/// ID perangkat berubah.
class DeviceBuilder extends StatefulWidget {
  const DeviceBuilder({
    super.key,
    required this.deviceId,
    required this.builder,
  });

  final String deviceId;
  final Widget Function(BuildContext, DeviceSnapshot?) builder;

  @override
  State<DeviceBuilder> createState() => _DeviceBuilderState();
}

class _DeviceBuilderState extends State<DeviceBuilder> {
  late Stream<DeviceSnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = context.read<FeederBackend>().watchDevice(widget.deviceId);
  }

  @override
  void didUpdateWidget(DeviceBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceId != widget.deviceId) {
      _stream = context.read<FeederBackend>().watchDevice(widget.deviceId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeviceSnapshot>(
      stream: _stream,
      builder: (context, snapshot) => widget.builder(context, snapshot.data),
    );
  }
}

/// Mendengarkan riwayat aktivitas satu perangkat.
class ActivityBuilder extends StatefulWidget {
  const ActivityBuilder({
    super.key,
    required this.deviceId,
    required this.builder,
  });

  final String deviceId;
  final Widget Function(BuildContext, List<ActivityEntry>?) builder;

  @override
  State<ActivityBuilder> createState() => _ActivityBuilderState();
}

class _ActivityBuilderState extends State<ActivityBuilder> {
  late Stream<List<ActivityEntry>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = context.read<FeederBackend>().watchActivity(
      widget.deviceId,
      limit: 100,
    );
  }

  @override
  void didUpdateWidget(ActivityBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceId != widget.deviceId) {
      _stream = context.read<FeederBackend>().watchActivity(
        widget.deviceId,
        limit: 100,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityEntry>>(
      stream: _stream,
      builder: (context, snapshot) => widget.builder(context, snapshot.data),
    );
  }
}
