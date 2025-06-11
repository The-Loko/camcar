// filepath: d:\Devs\Nihal\camcar\lib\widgets\joystick.dart
import 'package:flutter/material.dart';

typedef JoystickCallback = void Function(double x, double y);

class Joystick extends StatefulWidget {
  final double size;
  final JoystickCallback onChanged;

  const Joystick({super.key, this.size = 150, required this.onChanged});

  @override
  JoystickState createState() => JoystickState();
}

class JoystickState extends State<Joystick> {
  Offset _knobOffset = Offset.zero;
  late double _radius;

  @override
  void initState() {
    super.initState();
    _radius = widget.size / 2;
  }

  void _updateOffset(Offset localPosition) {
    final center = Offset(_radius, _radius);
    Offset offset = localPosition - center;
    if (offset.distance > _radius) {
      offset = Offset.fromDirection(offset.direction, _radius);
    }
    setState(() {
      _knobOffset = offset;
    });
    // Normalize to -1..1
    final normalizedX = (offset.dx / _radius);
    final normalizedY = -(offset.dy / _radius);
    widget.onChanged(normalizedX, normalizedY);
  }

  void _resetKnob() {
    setState(() {
      _knobOffset = Offset.zero;
    });
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => _updateOffset(details.localPosition),
      onPanUpdate: (details) => _updateOffset(details.localPosition),
      onPanEnd: (_) => _resetKnob(),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: Center(
          child: Stack(
            children: [
              Positioned(
                left: _radius + _knobOffset.dx - 20,
                top: _radius + _knobOffset.dy - 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration:                  const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
