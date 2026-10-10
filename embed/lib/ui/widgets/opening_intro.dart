import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Pembuka aplikasi dalam satu gerakan:
/// 0. di layar berwarna, "Halo!" muncul huruf demi huruf disusul "Selamat datang di ...", lalu keduanya memudar;
/// 1. layar berlubang di tengah, logo muncul di lubang itu, lalu lubang melebar sampai latar putih dan nama aplikasi
///    tampil bersama garis kemajuan;
/// 2. setelah [ready] selesai, logo dan tulisan mengecil dan memudar, lalu [onDone] dipanggil.
/// Ketuk layar saat sapaan untuk melewatinya. Logo boleh interaktif (misalnya ikan yang mendekati pakan yang
/// dijatuhkan); selama pengguna masih bermain dengan logo, pembuka menunggu sampai beberapa detik.
class OpeningIntro extends StatefulWidget {
  const OpeningIntro({
    super.key,
    required this.appName,
    required this.tagline,
    required this.mark,
    required this.colors,
    required this.paper,
    required this.accent,
    required this.onDone,
    this.ready,
    this.hint,
    this.ink = const Color(0xFF1B1D1C),
    this.displayFont,
    this.bodyFont,
  });

  final String appName;
  final String tagline;

  /// Logo yang muncul di tengah lubang, digambar dalam kotak 180 x 180.
  final Widget mark;

  /// Ajakan kecil di bawah garis kemajuan, misalnya "Ketuk untuk menjatuhkan pakan".
  final String? hint;

  /// Dua warna gradasi latar pembuka (atas ke bawah).
  final List<Color> colors;

  /// Warna latar di balik lubang; sebaiknya sama dengan latar layar pertama aplikasi.
  final Color paper;
  final Color accent;
  final Color ink;
  final Future<void>? ready;
  final VoidCallback onDone;
  final String? displayFont;
  final String? bodyFont;

  @override
  State<OpeningIntro> createState() => _OpeningIntroState();
}

class _OpeningIntroState extends State<OpeningIntro>
    with SingleTickerProviderStateMixin {
  static const _haloSec = 2.4, _enterSec = 2.0, _exitSec = .7, _hole = 92.0;
  static const _minHold = 1.2,
      _maxHold = 10.0,
      _quiet = 2.5; // detik: tampil minimal, menunggu maksimal, jeda bermain

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _h = 0,
      _e = 0,
      _x = 0,
      _hold = 0,
      _clock = 0; // kemajuan sapaan, masuk, keluar; lama menunggu; jam gerak
  double _poked = -10; // waktu terakhir logo disentuh
  bool _ready = false, _done = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    final ready = widget.ready;
    if (ready == null) {
      _ready = true;
    } else {
      // pembuka tetap berakhir walau pemuatan gagal; layar berikutnya yang menampilkan kesalahannya
      ready.whenComplete(() => _ready = true).ignore();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _ticker.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Satu langkah waktu. Selisih antarbingkai dibatasi 1/30 detik: bila ponsel sempat tersendat saat aplikasi baru
  /// dibuka, gerakan berhenti sejenak lalu berlanjut, bukan melompat ke akhir.
  void _tick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / 1e6, 1 / 30);
    _last = elapsed;
    _clock += dt;
    if (_h < 1) {
      _h = math.min(1, _h + dt / _haloSec);
    } else if (_e < 1) {
      _e = math.min(1, _e + dt / _enterSec);
    } else if (!_ready ||
        _hold < _minHold ||
        (_clock - _poked < _quiet && _hold < _maxHold)) {
      _hold +=
          dt; // tunggu pemuatan, lalu beri waktu bermain dengan logo selama pengguna masih menyentuhnya
    } else if (_x < 1) {
      _x = math.min(1, _x + dt / _exitSec);
    } else if (!_done) {
      _done = true;
      _ticker.stop();
      widget.onDone();
      return;
    }
    setState(() {});
  }

  void _skipHalo() {
    if (_h < .72) setState(() => _h = .72); // langsung ke bagian sapaan memudar
  }

  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);
  static double _ease(Curve c, double t) => c.transform(t);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: widget.paper,
    body: LayoutBuilder(builder: (context, box) => _stage(box.biggest)),
  );

  Widget _stage(Size size) {
    final e = _e, x = _x;
    final center = Offset(size.width / 2, math.min(size.height * .42, 380));
    final far = math.sqrt(
      math.pow(size.width / 2, 2) +
          math.pow(math.max(center.dy, size.height - center.dy), 2),
    );
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: widget.colors,
    );

    final widen = _ease(Curves.easeInOutCubic, _seg(e, .42, .84));
    final hole =
        _hole * _ease(Curves.easeOutBack, _seg(e, .05, .25)) +
        (far - _hole) * widen;
    final pop = _ease(Curves.easeOutBack, _seg(e, .14, .4));
    final words = _ease(Curves.easeOutCubic, _seg(e, .8, 1));
    final leave = _ease(Curves.easeInCubic, x);
    final colored =
        _h < 1 ||
        hole < math.sqrt(math.pow(size.width / 2, 2) + math.pow(center.dy, 2));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: colored ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _h < 1 ? _skipHalo : null,
        child: Stack(
          children: [
            if (_h < 1) ..._halo(center, gradient),
            if (_h == 1 && hole < far) ...[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: gradient),
                ),
              ),
              if (hole > 0)
                Positioned.fromRect(
                  rect: Rect.fromCircle(center: center, radius: hole),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.paper,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
            if (_h == 1 && e > .14 && leave < 1) ...[
              // cincin tipis yang menyebar dari logo saat lubang melebar
              if (widen > 0 && widen < 1)
                Positioned.fromRect(
                  rect: Rect.fromCircle(
                    center: center,
                    radius: 80 + 140 * widen,
                  ),
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.accent.withValues(
                            alpha: .35 * (1 - widen),
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fromRect(
                rect: Rect.fromCenter(center: center, width: 180, height: 180),
                child: Opacity(
                  opacity: _seg(e, .14, .24) * (1 - leave),
                  child: Transform.translate(
                    offset: Offset(0, -30 * leave),
                    child: Transform.scale(
                      scale:
                          (.35 + .65 * pop) *
                          (.82 + .18 * widen) *
                          (1 - .25 * leave),
                      child: Listener(
                        onPointerDown: (_) => _poked = _clock,
                        child: widget.mark,
                      ),
                    ),
                  ),
                ),
              ),
              if (words > 0)
                Positioned(
                  left: 32,
                  right: 32,
                  top: center.dy + 110,
                  child: Opacity(
                    opacity: words * (1 - leave),
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - words) + 10 * leave),
                      child: _title(),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tahap 0: setiap huruf "Halo!" naik dan memantul kecil secara berurutan, lalu sapaan memudar.
  List<Widget> _halo(Offset center, Gradient gradient) {
    const letters = 'Halo!';
    final out = _ease(Curves.easeInCubic, _seg(_h, .72, .94));
    final welcome = _ease(Curves.easeOutCubic, _seg(_h, .34, .52));
    return [
      Positioned.fill(
        child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: center.dy - 40,
        child: Opacity(
          opacity: 1 - out,
          child: Transform.scale(
            scale: 1 + .08 * out,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < letters.length; i++)
                  Builder(
                    builder: (_) {
                      final t = _seg(_h, .03 + i * .05, .22 + i * .05);
                      final up = _ease(Curves.easeOutBack, t);
                      return Opacity(
                        opacity: _ease(Curves.easeOut, t),
                        child: Transform.translate(
                          offset: Offset(0, 26 * (1 - up)),
                          child: Transform.scale(
                            scale: .7 + .3 * up,
                            child: Text(
                              letters[i],
                              style: TextStyle(
                                fontFamily: widget.displayFont,
                                fontSize: 52,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        left: 24,
        right: 24,
        top: center.dy + 34,
        child: Opacity(
          opacity: welcome * (1 - out),
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - welcome)),
            child: Text(
              'Selamat datang di ${widget.appName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: widget.bodyFont,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: .92),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _title() => Column(
    children: [
      Text(
        widget.appName,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: widget.displayFont,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: widget.ink,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        widget.tagline,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: widget.bodyFont,
          fontSize: 14,
          color: widget.ink.withValues(alpha: .62),
          height: 1.35,
        ),
      ),
      const SizedBox(height: 22),
      SizedBox(
        width: 150,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: _ready ? 1 : null,
            minHeight: 3,
            color: widget.accent,
            backgroundColor: widget.accent.withValues(alpha: .16),
          ),
        ),
      ),
      if (widget.hint != null) ...[
        const SizedBox(height: 12),
        Text(
          widget.hint!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: widget.bodyFont,
            fontSize: 12.5,
            color: widget.ink.withValues(alpha: .45),
          ),
        ),
      ],
    ],
  );
}
