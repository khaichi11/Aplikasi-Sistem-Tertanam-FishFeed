import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Animasi pembuka: akuarium kecil dengan ikan yang berenang. Butiran pakan
/// jatuh dari atas seperti saat alat FishFeed memberi makan, lalu ikan
/// berbalik dan mendekat untuk memakannya. Ketuk akuarium untuk menjatuhkan
/// pakan di titik itu. Semua digambar dengan kode, tanpa gambar dari luar.
class FeedingLoader extends StatefulWidget {
  const FeedingLoader({super.key, this.size = 180});

  final double size;

  @override
  State<FeedingLoader> createState() => _FeedingLoaderState();
}

class _Pellet {
  _Pellet(this.x, this.y);
  double x, y;
  double rest = 0; // lama sudah tergeletak di pasir
}

class _FeedingLoaderState extends State<FeedingLoader>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _rng = math.Random(7);
  final _pellets = <_Pellet>[];
  final _bubbles = <Offset>[];
  double _t = 0, _nextDrop = .8;
  Offset _fish = const Offset(.3, .55);
  Offset _vel = const Offset(.08, 0);
  double _facing = 1; // 1 menghadap kanan, -1 kiri, berubah perlahan
  double _gulp = 0; // sisa waktu mulut terbuka setelah makan

  static const _sand = .86;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _drop(double x, {double y = .06}) =>
      _pellets.add(_Pellet(x.clamp(.12, .88), y));

  void _tap(TapDownDetails d) {
    HapticFeedback.selectionClick();
    final p = d.localPosition / widget.size;
    // tiga butir sekaligus, sedikit berserakan seperti pakan yang ditabur
    for (final dx in const [-.03, 0.0, .035]) {
      _drop(p.dx + dx, y: (p.dy - .02).clamp(.06, .6));
    }
  }

  void _tick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / 1e6, 1 / 30);
    _last = elapsed;
    _t += dt;

    // pakan otomatis sesekali, seperti jadwal di alat
    _nextDrop -= dt;
    if (_nextDrop <= 0) {
      _drop(.2 + _rng.nextDouble() * .6);
      _nextDrop = 2.6 + _rng.nextDouble() * 1.4;
    }
    for (final p in _pellets) {
      if (p.y < _sand - .02) {
        p.y += dt * .11;
        p.x += math.sin(_t * 3 + p.y * 20) * dt * .02;
      } else {
        p.rest += dt;
      }
    }
    _pellets.removeWhere((p) => p.rest > 3);

    // ikan menuju butir terdekat; bila tidak ada, berenang santai mondar-mandir
    final mouth = _fish + Offset(.11 * _facing, .007);
    _Pellet? target;
    var best = double.infinity;
    for (final p in _pellets) {
      final d = (Offset(p.x, p.y) - mouth).distance;
      if (d < best) {
        best = d;
        target = p;
      }
    }
    final goal =
        target != null
            ? Offset(target.x - .11 * _facing, target.y)
            : Offset(
              .5 + .28 * math.sin(_t * .45),
              .5 + .1 * math.sin(_t * .9),
            );
    final speed = target != null ? .38 : .14;
    final desired = goal - _fish;
    final want =
        desired.distance < 1e-6
            ? Offset.zero
            : desired /
                desired.distance *
                math.min(speed, desired.distance * 3);
    _vel = Offset.lerp(_vel, want, math.min(1, dt * 3))!;
    _fish += _vel * dt;
    _fish = Offset(_fish.dx.clamp(.2, .8), _fish.dy.clamp(.22, .74));
    if (_vel.dx.abs() > .02) {
      _facing += ((_vel.dx > 0 ? 1 : -1) - _facing) * math.min(1, dt * 6);
    }
    if (target != null && best < .05) {
      _pellets.remove(target);
      _gulp = .35;
      _bubbles.add(mouth);
    }
    _gulp = math.max(0, _gulp - dt);

    // gelembung naik dari ikan dan dari dasar
    if (_rng.nextDouble() < dt * 1.2) {
      _bubbles.add(Offset(.15 + _rng.nextDouble() * .7, _sand));
    }
    for (var i = 0; i < _bubbles.length; i++) {
      final b = _bubbles[i];
      _bubbles[i] = Offset(
        b.dx + math.sin(_t * 4 + i) * dt * .02,
        b.dy - dt * .16,
      );
    }
    _bubbles.removeWhere((b) => b.dy < .1);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ikan mendekati pakan',
    child: GestureDetector(
      onTapDown: _tap,
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _TankPainter(
            t: _t,
            fish: _fish,
            facing: _facing,
            gulp: _gulp,
            pellets: [for (final p in _pellets) Offset(p.x, p.y)],
            bubbles: List.of(_bubbles),
          ),
        ),
      ),
    ),
  );
}

class _TankPainter extends CustomPainter {
  _TankPainter({
    required this.t,
    required this.fish,
    required this.facing,
    required this.gulp,
    required this.pellets,
    required this.bubbles,
  });

  final double t, facing, gulp;
  final Offset fish;
  final List<Offset> pellets, bubbles;

  static const _ocean = Color(0xFF0E6E7E);
  static const _teal = Color(0xFF2B8A99);
  static const _coral = Color(0xFFE8A33D);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.save();
    canvas.scale(s);
    final tank = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 1, 1),
      const Radius.circular(.22),
    );
    canvas.clipRRect(tank);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_teal, _ocean],
        ).createShader(const Rect.fromLTWH(0, 0, 1, 1)),
    );
    // berkas cahaya dari permukaan
    final ray = Paint()..color = const Color(0x12FFFFFF);
    for (final x in const [.18, .52, .8]) {
      final sway = math.sin(t * .8 + x * 6) * .04;
      canvas.drawPath(
        Path()
          ..moveTo(x - .05, 0)
          ..lineTo(x + .05, 0)
          ..lineTo(x + .14 + sway, 1)
          ..lineTo(x + .02 + sway, 1)
          ..close(),
        ray,
      );
    }
    // rumput laut bergoyang
    final weed =
        Paint()
          ..color = const Color(0xFF3FA37A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .028
          ..strokeCap = StrokeCap.round;
    for (final (x, h) in const [(.14, .3), (.2, .22), (.84, .26)]) {
      final sway = math.sin(t * 1.4 + x * 9) * .03;
      canvas.drawPath(
        Path()
          ..moveTo(x, .9)
          ..quadraticBezierTo(x + sway, .9 - h / 2, x + sway * 1.6, .9 - h),
        weed,
      );
    }
    // pasir
    canvas.drawPath(
      Path()
        ..moveTo(0, .88)
        ..quadraticBezierTo(.3, .84, .55, .87)
        ..quadraticBezierTo(.8, .9, 1, .86)
        ..lineTo(1, 1)
        ..lineTo(0, 1)
        ..close(),
      Paint()..color = const Color(0xFFE9D8A6),
    );
    // butir pakan
    final pellet = Paint()..color = const Color(0xFF9A5B2B);
    for (final p in pellets) {
      canvas.drawCircle(p, .013, pellet);
    }
    _fishShape(canvas);
    // gelembung
    final bubble =
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .006;
    for (final b in bubbles) {
      canvas.drawCircle(b, .014, bubble);
    }
    canvas.restore();
  }

  void _fishShape(Canvas canvas) {
    canvas.save();
    canvas.translate(fish.dx, fish.dy + math.sin(t * 3) * .006);
    canvas.scale(facing * 1.5, 1.5);
    final wag = math.sin(t * 9) * .025;
    final tail =
        Path()
          ..moveTo(-.055, 0)
          ..lineTo(-.11, -.045 + wag)
          ..quadraticBezierTo(-.095, 0, -.11, .045 + wag)
          ..close();
    canvas.drawPath(tail, Paint()..color = const Color(0xFFD98B22));
    final body =
        Path()
          ..moveTo(-.065, 0)
          ..quadraticBezierTo(-.02, -.06, .05, -.025)
          ..quadraticBezierTo(.075, -.01, .075, 0)
          ..quadraticBezierTo(.075, .01, .05, .025)
          ..quadraticBezierTo(-.02, .06, -.065, 0)
          ..close();
    canvas.drawPath(body, Paint()..color = _coral);
    // sirip punggung dan garis tubuh
    canvas.drawPath(
      Path()
        ..moveTo(-.02, -.038)
        ..quadraticBezierTo(.0, -.07, .025, -.032)
        ..close(),
      Paint()..color = const Color(0xFFD98B22),
    );
    canvas.drawLine(
      const Offset(.02, -.03),
      const Offset(.02, .03),
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..strokeWidth = .008,
    );
    canvas.drawCircle(
      const Offset(.045, -.008),
      .011,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      const Offset(.048, -.008),
      .006,
      Paint()..color = const Color(0xFF14323A),
    );
    // mulut terbuka sebentar setelah makan
    if (gulp > 0) {
      canvas.drawCircle(
        const Offset(.075, .002),
        .01 * math.sin(gulp / .35 * math.pi),
        Paint()..color = const Color(0xFF7A3E12),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TankPainter old) => true;
}
