import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Draws a yellow highlighter mark behind [child]: a slightly rotated
/// (−1.5°), irregularly rounded rectangle covering the lower half of the
/// text. It sweeps in from left to right once, unless the phone's Reduce
/// Motion setting is on.
class Highlighter extends StatefulWidget {
  const Highlighter({super.key, required this.child, this.animate = true, this.color});

  final Widget child;
  final bool animate;
  final Color? color;

  @override
  State<Highlighter> createState() => _HighlighterState();
}

class _HighlighterState extends State<Highlighter> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _sweep = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.animate || reduceMotion) {
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
    final color = widget.color ?? AppColors.of(context).highlight;
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, child) => CustomPaint(
        painter: _HighlighterPainter(progress: _sweep.value, color: color),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: widget.child,
      ),
    );
  }
}

class _HighlighterPainter extends CustomPainter {
  _HighlighterPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    // Covers roughly the lower half of the digits, slightly past both ends.
    final top = size.height * 0.48;
    final bottom = size.height * 0.92;
    final left = -2.0;
    final fullRight = size.width + 2;
    final right = left + (fullRight - left) * progress;
    final rect = Rect.fromLTRB(left, top, right, bottom);
    // Irregular corners, like a real marker stroke.
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.elliptical(10, 6),
      bottomLeft: const Radius.elliptical(4, 9),
      topRight: const Radius.elliptical(5, 10),
      bottomRight: const Radius.elliptical(12, 5),
    );
    canvas.save();
    canvas.translate(size.width / 2, (top + bottom) / 2);
    canvas.rotate(-1.5 * math.pi / 180);
    canvas.translate(-size.width / 2, -(top + bottom) / 2);
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.9));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HighlighterPainter old) => old.progress != progress || old.color != color;
}
