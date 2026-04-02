import 'dart:math' as math;
import 'package:flutter/material.dart';

class SquigglySlider extends StatefulWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final Color activeColor;
  final Color inactiveColor;
  final double trackHeight;
  final double thumbRadius;
  final bool isPlaying;

  const SquigglySlider({
    super.key,
    required this.value,
    this.max = 1.0,
    required this.onChanged,
    this.activeColor = Colors.white,
    this.inactiveColor = Colors.white24,
    this.trackHeight = 4.0,
    this.thumbRadius = 6.0,
    this.isPlaying = true,
  });

  @override
  State<SquigglySlider> createState() => _SquigglySliderState();
}

class _SquigglySliderState extends State<SquigglySlider> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Tracks whether the user is actively dragging so we can show a bigger thumb
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void didUpdateWidget(SquigglySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_isDragging) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (!widget.isPlaying && !_isDragging) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Converts a global or local x offset into a playback value and fires onChanged
  void _updateValue(BuildContext context, double localX) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final double percent = (localX / box.size.width).clamp(0.0, 1.0);
    widget.onChanged(percent * widget.max);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Tap: jump to tapped position immediately
      onTapDown: (details) {
        _updateValue(context, details.localPosition.dx);
      },
      // Drag start: snap to finger and start drag mode
      onHorizontalDragStart: (details) {
        setState(() => _isDragging = true);
        _updateValue(context, details.localPosition.dx);
      },
      // Drag update: follow finger smoothly
      onHorizontalDragUpdate: (details) {
        _updateValue(context, details.localPosition.dx);
      },
      // Drag end: restore normal state
      onHorizontalDragEnd: (_) {
        setState(() => _isDragging = false);
      },
      onHorizontalDragCancel: () {
        setState(() => _isDragging = false);
      },
      child: SizedBox(
        height: 44, // Generous hit area
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(double.infinity, 44),
              painter: _SquigglyPainter(
                value: widget.value / (widget.max == 0 ? 1 : widget.max),
                phase: _controller.value,
                activeColor: widget.activeColor,
                inactiveColor: widget.inactiveColor,
                trackHeight: widget.trackHeight,
                // Thumb grows while dragging for tactile feedback
                thumbRadius: _isDragging ? widget.thumbRadius * 1.6 : widget.thumbRadius,
                isPlaying: widget.isPlaying,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SquigglyPainter extends CustomPainter {
  final double value;
  final double phase;
  final Color activeColor;
  final Color inactiveColor;
  final double trackHeight;
  final double thumbRadius;
  final bool isPlaying;

  _SquigglyPainter({
    required this.value,
    required this.phase,
    required this.activeColor,
    required this.inactiveColor,
    required this.trackHeight,
    required this.thumbRadius,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    final double thumbX = (size.width * value).clamp(0.0, size.width);

    // --- Inactive (future) track — flat line ---
    final Paint inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = trackHeight
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (thumbX < size.width) {
      canvas.drawLine(
        Offset(thumbX + thumbRadius, centerY),
        Offset(size.width, centerY),
        inactivePaint,
      );
    }

    // --- Active (played) track ---
    if (thumbX > 0) {
      final Paint activePaint = Paint()
        ..color = activeColor
        ..strokeWidth = trackHeight
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (isPlaying) {
        // Squiggly animated line while playing
        const double amplitude = 3.5;
        const double wavelength = 18.0;
        final Path path = Path();
        path.moveTo(0, centerY);
        for (double x = 0; x <= thumbX; x += 1.0) {
          final double y = centerY + amplitude * math.sin((x / wavelength) * 2 * math.pi + (phase * 2 * math.pi));
          path.lineTo(x, y);
        }
        canvas.drawPath(path, activePaint);
      } else {
        // Flat line when paused
        canvas.drawLine(Offset(0, centerY), Offset(thumbX, centerY), activePaint);
      }
    }

    // --- Thumb circle ---
    final Paint thumbPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    // Outer glow ring
    final Paint glowPaint = Paint()
      ..color = activeColor.withAlpha(50)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(thumbX, centerY), thumbRadius + 4, glowPaint);
    canvas.drawCircle(Offset(thumbX, centerY), thumbRadius, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _SquigglyPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.phase != phase ||
        oldDelegate.thumbRadius != thumbRadius ||
        oldDelegate.isPlaying != isPlaying;
  }
}
