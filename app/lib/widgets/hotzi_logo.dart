import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Logo « Lever de soleil » : deux ondes, un demi-soleil et l'horizon.
/// Avec [animate], le soleil se lève à l'affichage.
class HotziLogo extends StatefulWidget {
  const HotziLogo({
    super.key,
    this.size = 40,
    this.arcColor = Colors.white,
    this.sunColor = HotziColors.mango,
    this.animate = false,
  });

  final double size;
  final Color arcColor;
  final Color sunColor;
  final bool animate;

  @override
  State<HotziLogo> createState() => _HotziLogoState();
}

class _HotziLogoState extends State<HotziLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _rise = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.value > 0 || _controller.isAnimating) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hotzi',
      image: true,
      child: AnimatedBuilder(
        animation: _rise,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _LogoPainter(widget.arcColor, widget.sunColor, _rise.value),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.arcColor, this.sunColor, this.rise);

  final Color arcColor;
  final Color sunColor;
  final double rise;

  static const _center = Offset(50, 62);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    final stroke = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    for (final radius in const [38.0, 24.0]) {
      canvas.drawArc(Rect.fromCircle(center: _center, radius: radius), pi, pi, false, stroke);
    }

    // Le soleil sort de derrière l'horizon.
    canvas
      ..save()
      ..clipRect(const Rect.fromLTRB(0, 0, 100, 72))
      ..translate(0, (1 - rise) * 18);
    canvas.drawArc(
      Rect.fromCircle(center: _center, radius: 14),
      pi,
      pi,
      true,
      Paint()..color = sunColor.withValues(alpha: sunColor.a * rise),
    );
    canvas
      ..restore()
      ..drawLine(const Offset(16, 76), const Offset(84, 76), stroke);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.rise != rise || old.arcColor != arcColor || old.sunColor != sunColor;
}
