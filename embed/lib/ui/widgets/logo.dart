import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Logo FishFeed: ikan putih dengan butiran pakan, di atas ubin biru laut.
class FishFeedLogo extends StatelessWidget {
  const FishFeedLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo FishFeed',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: FishFeedLogoPainter()),
      ),
    );
  }
}

class FishFeedLogoPainter extends CustomPainter {
  const FishFeedLogoPainter({this.background = true});

  final bool background;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (background) {
      final rect = Offset.zero & Size.square(s);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * 0.28)),
        Paint()..color = AppColors.ocean,
      );
    }
    // Fish body.
    final body =
        Path()
          ..moveTo(s * 0.20, s * 0.56)
          ..quadraticBezierTo(s * 0.42, s * 0.30, s * 0.66, s * 0.48)
          ..quadraticBezierTo(s * 0.72, s * 0.53, s * 0.66, s * 0.58)
          ..quadraticBezierTo(s * 0.42, s * 0.78, s * 0.20, s * 0.56)
          ..close();
    // Tail.
    final tail =
        Path()
          ..moveTo(s * 0.62, s * 0.53)
          ..lineTo(s * 0.82, s * 0.40)
          ..quadraticBezierTo(s * 0.77, s * 0.53, s * 0.82, s * 0.66)
          ..close();
    final white = Paint()..color = Colors.white;
    canvas.drawPath(tail, white);
    canvas.drawPath(body, white);
    // Eye.
    canvas.drawCircle(
      Offset(s * 0.32, s * 0.52),
      s * 0.035,
      Paint()..color = AppColors.oceanDeep,
    );
    // Falling pellets.
    final pellet = Paint()..color = AppColors.coral;
    canvas.drawCircle(Offset(s * 0.30, s * 0.20), s * 0.045, pellet);
    canvas.drawCircle(Offset(s * 0.42, s * 0.14), s * 0.035, pellet);
    canvas.drawCircle(Offset(s * 0.22, s * 0.31), s * 0.03, pellet);
  }

  @override
  bool shouldRepaint(FishFeedLogoPainter oldDelegate) =>
      oldDelegate.background != background;
}
