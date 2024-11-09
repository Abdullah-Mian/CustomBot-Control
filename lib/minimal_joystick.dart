import 'package:flutter/material.dart';

class MinimalJoystick extends StatelessWidget {
  final Map<String, Function> callbacks;

  const MinimalJoystick({super.key, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
        borderRadius: BorderRadius.circular(75),
      ),
      child: Stack(
        children: [
          _buildDirectionButton(
            Alignment.topCenter,
            '↑',
            callbacks['onForward']!,
          ),
          _buildDirectionButton(
            Alignment.bottomCenter,
            '↓',
            callbacks['onBackward']!,
          ),
          _buildDirectionButton(
            Alignment.centerLeft,
            '←',
            callbacks['onLeft']!,
          ),
          _buildDirectionButton(
            Alignment.centerRight,
            '→',
            callbacks['onRight']!,
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionButton(
    Alignment alignment,
    String label,
    Function onPressed,
  ) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTapDown: (_) => onPressed(),
        onTapUp: (_) => callbacks['onRelease']!(),
        onTapCancel: () => callbacks['onRelease']!(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 20,
              ),
            ),
            ),
        ),
      ),
    );
  }
}
