import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Cincin progres dengan isi di tengah.
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.value,
    required this.color,
    required this.child,
    this.size = 84,
    this.stroke = 9,
  });

  /// 0 sampai 1.
  final double value;
  final Color color;
  final Widget child;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder:
            (context, animated, _) => CustomPaint(
              painter: _RingPainter(animated, color, stroke),
              child: Center(child: child),
            ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.stroke);

  final double value;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

/// Grafik batang sederhana untuk jumlah pemberian pakan per hari.
class WeeklyBars extends StatelessWidget {
  const WeeklyBars({
    super.key,
    required this.values,
    required this.labels,
    this.height = 120,
  });

  final List<int> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = values.fold<int>(1, math.max);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Semantics(
                label: '${labels[i]}: ${values[i]} kali',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${values[i]}', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: values[i] / top),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder:
                              (context, fraction, _) => FractionallySizedBox(
                                heightFactor: math.max(0.04, fraction),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        i == values.length - 1
                                            ? AppColors.coral
                                            : AppColors.ocean.withValues(
                                              alpha: 0.75,
                                            ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: i == values.length - 1 ? AppColors.ink : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
