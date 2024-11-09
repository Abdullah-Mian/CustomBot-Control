import 'package:flutter/material.dart';

class ClassicJoystick extends StatelessWidget {
  final Map<String, Function> callbacks;

  const ClassicJoystick({super.key, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDirectionButton('↑', callbacks['onForward']!),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDirectionButton('←', callbacks['onLeft']!),
            const SizedBox(width: 60),
            _buildDirectionButton('→', callbacks['onRight']!),
          ],
        ),
        _buildDirectionButton('↓', callbacks['onBackward']!),
      ],
    );
  }

  Widget _buildDirectionButton(String label, Function onPressed) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => callbacks['onRelease']!(),
      onTapCancel: () => callbacks['onRelease']!(),
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
