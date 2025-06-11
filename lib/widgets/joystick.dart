import 'package:flutter/material.dart';
import 'dart:math' as math;

typedef JoystickCallback = void Function(double x, double y);

class Joystick extends StatefulWidget {
  final double size;
  final JoystickCallback onChanged;

  const Joystick({super.key, this.size = 150, required this.onChanged});

  @override
  JoystickState createState() => JoystickState();
}

class JoystickState extends State<Joystick> {
  Offset _knobPosition = Offset.zero;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final double radius = widget.size / 2;
    final double knobRadius = radius * 0.3;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final Offset localPosition = renderBox.globalToLocal(details.globalPosition);
          final Offset center = Offset(radius, radius);
          final Offset delta = localPosition - center;
          final double distance = delta.distance;

          if (distance <= radius - knobRadius) {
            setState(() {
              _knobPosition = delta;
            });
          } else {
            final Offset normalized = delta / distance;
            setState(() {
              _knobPosition = normalized * (radius - knobRadius);
            });
          }

          // Normalize values to -1.0 to 1.0 range
          final double normalizedX = _knobPosition.dx / (radius - knobRadius);
          final double normalizedY = -_knobPosition.dy / (radius - knobRadius); // Invert Y axis
          
          widget.onChanged(normalizedX, normalizedY);
        },
        onPanEnd: (details) {
          setState(() {
            _knobPosition = Offset.zero;
            _isDragging = false;
          });
          widget.onChanged(0, 0);
        },
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _JoystickPainter(
            knobPosition: _knobPosition,
            isDragging: _isDragging,
            radius: radius,
            knobRadius: knobRadius,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset knobPosition;
  final bool isDragging;
  final double radius;
  final double knobRadius;

  _JoystickPainter({
    required this.knobPosition,
    required this.isDragging,
    required this.radius,
    required this.knobRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint basePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Paint knobPaint = Paint()
      ..color = isDragging 
          ? Colors.white.withOpacity(0.9)
          : Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final Paint knobShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final Offset center = Offset(radius, radius);

    // Draw base circle (invisible boundary)
    canvas.drawCircle(center, radius - 4, basePaint);
    canvas.drawCircle(center, radius - 4, borderPaint);

    // Draw center dot
    canvas.drawCircle(center, 3, Paint()
      ..color = Colors.white.withOpacity(0.3));

    // Draw knob shadow
    canvas.drawCircle(
      center + knobPosition + const Offset(2, 2),
      knobRadius,
      knobShadowPaint,
    );

    // Draw knob
    canvas.drawCircle(
      center + knobPosition,
      knobRadius,
      knobPaint,
    );

    // Draw knob highlight
    canvas.drawCircle(
      center + knobPosition - Offset(knobRadius * 0.3, knobRadius * 0.3),
      knobRadius * 0.3,
      Paint()..color = Colors.white.withOpacity(0.4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
