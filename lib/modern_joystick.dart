import 'package:flutter/material.dart';

class ModernJoystick extends StatelessWidget {
  final Map<String, Function> callbacks;

  const ModernJoystick({super.key, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            left: 75,
            child: _buildTouchArea('↑', callbacks['onForward']!),
          ),
          Positioned(
            bottom: 10,
            left: 75,
            child: _buildTouchArea('↓', callbacks['onBackward']!),
          ),
          Positioned(
            left: 10,
            top: 75,
            child: _buildTouchArea('←', callbacks['onLeft']!),
          ),
          Positioned(
            right: 10,
            top: 75,
            child: _buildTouchArea('→', callbacks['onRight']!),
          ),
        ],
      ),
    );
  }

  Widget _buildTouchArea(String label, Function onPressed) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => callbacks['onRelease']!(),
      onTapCancel: () => callbacks['onRelease']!(),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 20,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }
}
