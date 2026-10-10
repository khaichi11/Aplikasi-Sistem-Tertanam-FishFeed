import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Pembuka FishFeed: panel air bersudut membulat naik dari bawah sampai memenuhi layar, lalu seluruh layar menjadi
/// akuarium. Tiga ikan berenang, butiran pakan sesekali jatuh seperti saat alat bekerja, dan ikan berbalik mendekat
/// untuk memakannya. Ketuk di mana saja untuk menabur pakan di titik itu. Setelah [ready] selesai, akuarium memudar
/// dan [onDone] dipanggil; selama pengguna masih memberi makan, pembuka menunggu sampai beberapa detik.
class AquariumIntro extends StatefulWidget {
  const AquariumIntro({super.key, required this.onDone, this.ready});

  final Future<void>? ready;
  final VoidCallback onDone;

  @override
  State<AquariumIntro> createState() => _AquariumIntroState();
}

class _Fish {
  _Fish(this.pos, this.color, this.fin, this.scale, this.home);
  Offset pos;
  Offset vel = Offset.zero;
  double facing = 1; // 1 menghadap kanan, -1 kiri, berubah perlahan
  double gulp = 0;
  final Color color, fin;
  final double scale;
  final double home; // pergeseran fase berenang santai
}

class _Pellet {
  _Pellet(this.pos);
  Offset pos;
  double rest = 0;
}

class _AquariumIntroState extends State<AquariumIntro>
    with SingleTickerProviderStateMixin {
  static const _riseSec = 1.1, _greetSec = 2.2, _exitSec = .7;
  static const _minHold = 1.5, _maxHold = 10.0, _quiet = 2.5;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _rng = math.Random(11);
  final _pellets = <_Pellet>[];
  final _bubbles = <Offset>[];
  final _fish = <_Fish>[];
  Size _size = Size.zero;
  double _clock = 0, _rise = 0, _greet = 0, _hold = 0, _exit = 0;
  double _nextDrop = 1.6, _poked = -10;
  bool _ready = false, _done = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    final ready = widget.ready;
    if (ready == null) {
      _ready = true;
    } else {
      ready.whenComplete(() => _ready = true).ignore();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _ticker.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _spawnFish() {
    final w = _size.width, h = _size.height;
    _fish.addAll([
      _Fish(
        Offset(w * .25, h * .58),
        AppColors.coral,
        const Color(0xFFD98B22),
        1.0,
        0,
      ),
      _Fish(
        Offset(w * .7, h * .7),
        const Color(0xFFF2C14E),
        const Color(0xFFE0A126),
        .72,
        2,
      ),
      _Fish(
        Offset(w * .55, h * .48),
        const Color(0xFFEF8A6B),
        const Color(0xFFD9694A),
        .6,
        4,
      ),
    ]);
  }

  void _drop(Offset at) {
    final w = _size.width;
    _pellets.add(_Pellet(Offset(at.dx.clamp(w * .06, w * .94), at.dy)));
  }

  void _tap(TapDownDetails d) {
    if (_rise < 1) return;
    HapticFeedback.selectionClick();
    _poked = _clock;
    for (final dx in const [-14.0, 0.0, 16.0]) {
      _drop(d.localPosition + Offset(dx, (dx.abs() - 8) * .4));
    }
  }

  /// Selisih antarbingkai dibatasi 1/30 detik supaya gerakan tidak melompat saat ponsel sempat tersendat.
  void _tick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / 1e6, 1 / 30);
    _last = elapsed;
    _clock += dt;
    if (_size == Size.zero) return;
    if (_fish.isEmpty) _spawnFish();
    if (_rise < 1) {
      _rise = math.min(1, _rise + dt / _riseSec);
    } else if (_greet < 1) {
      _greet = math.min(1, _greet + dt / _greetSec);
    } else if (!_ready ||
        _hold < _minHold ||
        (_clock - _poked < _quiet && _hold < _maxHold)) {
      _hold += dt;
    } else if (_exit < 1) {
      _exit = math.min(1, _exit + dt / _exitSec);
    } else if (!_done) {
      _done = true;
      _ticker.stop();
      widget.onDone();
      return;
    }
    _simulate(dt);
    setState(() {});
  }

  void _simulate(double dt) {
    final w = _size.width, h = _size.height;
    final sand = h * .9;
    if (_rise >= 1) {
      _nextDrop -= dt;
      if (_nextDrop <= 0) {
        _drop(Offset(w * (.15 + _rng.nextDouble() * .7), h * .16));
        _nextDrop = 2.2 + _rng.nextDouble() * 1.3;
      }
    }
    for (final p in _pellets) {
      if (p.pos.dy < sand - 6) {
        p.pos += Offset(
          math.sin(_clock * 3 + p.pos.dy / 20) * 8 * dt,
          h * .09 * dt,
        );
      } else {
        p.rest += dt;
      }
    }
    _pellets.removeWhere((p) => p.rest > 3);

    final taken = <_Pellet>{};
    for (final f in _fish) {
      final len = w * .17 * f.scale;
      final mouth = f.pos + Offset(len * .48 * f.facing, 0);
      _Pellet? target;
      var best = double.infinity;
      for (final p in _pellets) {
        if (taken.contains(p)) continue;
        final d = (p.pos - mouth).distance;
        if (d < best) {
          best = d;
          target = p;
        }
      }
      if (target != null) taken.add(target);
      final goal =
          target != null
              ? target.pos - Offset(len * .48 * f.facing, 0)
              : Offset(
                w * (.5 + .32 * math.sin(_clock * .4 + f.home)),
                h * (.55 + .15 * math.sin(_clock * .7 + f.home * 1.7)),
              );
      final speed = (target != null ? .45 : .14) * w;
      final desired = goal - f.pos;
      final want =
          desired.distance < 1e-6
              ? Offset.zero
              : desired /
                  desired.distance *
                  math.min(speed, desired.distance * 3);
      f.vel = Offset.lerp(f.vel, want, math.min(1, dt * 3))!;
      f.pos += f.vel * dt;
      f.pos = Offset(
        f.pos.dx.clamp(len * .6, w - len * .6),
        f.pos.dy.clamp(h * .3, sand - len * .4),
      );
      if (f.vel.dx.abs() > w * .02) {
        f.facing += ((f.vel.dx > 0 ? 1 : -1) - f.facing) * math.min(1, dt * 6);
      }
      if (target != null && best < len * .22) {
        _pellets.remove(target);
        f.gulp = .35;
        _bubbles.add(mouth);
      }
      f.gulp = math.max(0, f.gulp - dt);
    }

    if (_rng.nextDouble() < dt * 2.2) {
      _bubbles.add(Offset(w * (.08 + _rng.nextDouble() * .84), sand));
    }
    for (var i = 0; i < _bubbles.length; i++) {
      final b = _bubbles[i];
      _bubbles[i] = Offset(
        b.dx + math.sin(_clock * 4 + i) * 10 * dt,
        b.dy - h * .12 * dt,
      );
    }
    _bubbles.removeWhere((b) => b.dy < h * .08);
  }

  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, box) {
          _size = box.biggest;
          final rise = Curves.easeOutCubic.transform(_rise);
          final fade = 1 - Curves.easeInCubic.transform(_exit);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value:
                rise > .9 && fade > .5
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _tap,
              child: Opacity(
                opacity: fade,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TankPainter(
                          clock: _clock,
                          rise: rise,
                          fish: _fish,
                          pellets: [for (final p in _pellets) p.pos],
                          bubbles: List.of(_bubbles),
                        ),
                      ),
                    ),
                    if (_rise >= 1) _words(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Sapaan mengapung di air, lalu berganti menjadi nama aplikasi dan garis kemajuan.
  Widget _words() {
    final hello = Curves.easeOutCubic.transform(_seg(_greet, 0, .25));
    final swap = Curves.easeInOutCubic.transform(_seg(_greet, .55, .8));
    final bob = math.sin(_clock * 2) * 4;
    final top = _size.height * .16;
    TextStyle display(double size) => TextStyle(
      fontFamily: 'Poppins',
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      height: 1.1,
    );
    TextStyle body(double size, double alpha) => TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: alpha),
    );
    return Positioned(
      left: 24,
      right: 24,
      top: top + bob,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Opacity(
            opacity: hello * (1 - swap),
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - hello) - 16 * swap),
              child: Column(
                children: [
                  Text('Halo!', style: display(52)),
                  const SizedBox(height: 10),
                  Text('Selamat datang di FishFeed', style: body(17, .9)),
                ],
              ),
            ),
          ),
          Opacity(
            opacity: swap,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - swap)),
              child: Column(
                children: [
                  Text('FishFeed', style: display(34)),
                  const SizedBox(height: 4),
                  Text('Pemberi pakan ikan otomatis', style: body(14, .82)),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _ready ? 1 : null,
                        minHeight: 3,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: .25),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Ketuk air untuk menabur pakan', style: body(12.5, .7)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TankPainter extends CustomPainter {
  _TankPainter({
    required this.clock,
    required this.rise,
    required this.fish,
    required this.pellets,
    required this.bubbles,
  });

  final double clock, rise;
  final List<_Fish> fish;
  final List<Offset> pellets, bubbles;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // panel air bersudut membulat naik dari bawah sampai menutup layar
    final top = (h + 40) * (1 - rise) - 40;
    final radius = Radius.circular(32 * (1 - rise));
    final water = RRect.fromLTRBAndCorners(
      0,
      top,
      w,
      h + 40,
      topLeft: radius,
      topRight: radius,
    );
    canvas.save();
    canvas.clipRRect(water);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.teal, AppColors.ocean, AppColors.oceanDeep],
        ).createShader(Offset.zero & size),
    );
    // berkas cahaya dari permukaan
    final ray = Paint()..color = const Color(0x10FFFFFF);
    for (final x in const [.12, .42, .7, .92]) {
      final sway = math.sin(clock * .7 + x * 6) * w * .05;
      canvas.drawPath(
        Path()
          ..moveTo(w * (x - .05), 0)
          ..lineTo(w * (x + .04), 0)
          ..lineTo(w * (x + .16) + sway, h)
          ..lineTo(w * (x + .02) + sway, h)
          ..close(),
        ray,
      );
    }
    // rumput laut dan pasir
    final weed =
        Paint()
          ..color = const Color(0xFF3FA37A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .022
          ..strokeCap = StrokeCap.round;
    for (final (x, len) in const [
      (.08, .26),
      (.13, .18),
      (.18, .22),
      (.82, .2),
      (.88, .28),
      (.93, .16),
    ]) {
      final sway = math.sin(clock * 1.3 + x * 9) * w * .03;
      final base = h * .91;
      canvas.drawPath(
        Path()
          ..moveTo(w * x, base)
          ..quadraticBezierTo(
            w * x + sway,
            base - h * len / 2,
            w * x + sway * 1.6,
            base - h * len,
          ),
        weed,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(0, h * .9)
        ..quadraticBezierTo(w * .3, h * .87, w * .55, h * .895)
        ..quadraticBezierTo(w * .8, h * .92, w, h * .885)
        ..lineTo(w, h + 40)
        ..lineTo(0, h + 40)
        ..close(),
      Paint()..color = const Color(0xFFE9D8A6),
    );
    final stone = Paint()..color = const Color(0xFFCDBB8C);
    for (final (x, r) in const [
      (.3, .022),
      (.36, .014),
      (.66, .018),
      (.72, .026),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * x, h * .925),
          width: w * r * 2.2,
          height: w * r * 1.3,
        ),
        stone,
      );
    }
    final pellet = Paint()..color = const Color(0xFF9A5B2B);
    for (final p in pellets) {
      canvas.drawCircle(p, w * .011, pellet);
    }
    for (final f in fish) {
      _drawFish(canvas, f, w);
    }
    final bubble =
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
    for (final b in bubbles) {
      canvas.drawCircle(b, w * .012, bubble);
    }
    canvas.restore();
  }

  void _drawFish(Canvas canvas, _Fish f, double w) {
    final s = w * .17 * f.scale; // panjang ikan dalam piksel
    canvas.save();
    canvas.translate(
      f.pos.dx,
      f.pos.dy + math.sin(clock * 3 + f.home) * s * .03,
    );
    canvas.scale(f.facing * s, s);
    final wag = math.sin(clock * 9 + f.home) * .1;
    canvas.drawPath(
      Path()
        ..moveTo(-.36, 0)
        ..lineTo(-.62, -.24 + wag)
        ..quadraticBezierTo(-.54, 0, -.62, .24 + wag)
        ..close(),
      Paint()..color = f.fin,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-.42, 0)
        ..quadraticBezierTo(-.12, -.36, .3, -.15)
        ..quadraticBezierTo(.46, -.06, .46, 0)
        ..quadraticBezierTo(.46, .06, .3, .15)
        ..quadraticBezierTo(-.12, .36, -.42, 0)
        ..close(),
      Paint()..color = f.color,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-.12, -.23)
        ..quadraticBezierTo(0, -.42, .16, -.2)
        ..close(),
      Paint()..color = f.fin,
    );
    canvas.drawLine(
      const Offset(.12, -.18),
      const Offset(.12, .18),
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..strokeWidth = .045,
    );
    canvas.drawCircle(
      const Offset(.28, -.05),
      .065,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      const Offset(.3, -.05),
      .035,
      Paint()..color = const Color(0xFF14323A),
    );
    if (f.gulp > 0) {
      canvas.drawCircle(
        const Offset(.46, .01),
        .06 * math.sin(f.gulp / .35 * math.pi),
        Paint()..color = const Color(0xFF7A3E12),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TankPainter old) => true;
}
