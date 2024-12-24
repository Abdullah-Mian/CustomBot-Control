import 'package:flutter/material.dart';

class ModernJoystick extends StatelessWidget {
  final Map<String, Function> callbacks;

  const ModernJoystick({super.key, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colorScheme.secondary.withOpacity(0.15),
            colorScheme.surface.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: colorScheme.secondary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.secondary.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          _buildTouchArea('↑', callbacks['onForward']!, colorScheme, Alignment.topCenter),
          _buildTouchArea('↓', callbacks['onBackward']!, colorScheme, Alignment.bottomCenter),
          _buildTouchArea('←', callbacks['onLeft']!, colorScheme, Alignment.centerLeft),
          _buildTouchArea('→', callbacks['onRight']!, colorScheme, Alignment.centerRight),
        ],
      ),
    );
  }

  Widget _buildTouchArea(String label, Function onPressed, ColorScheme colorScheme, Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 0.9),
          duration: const Duration(milliseconds: 150),
          builder: (context, scale, child) {
            return GestureDetector(
              onTapDown: (_) => onPressed(),
              onTapUp: (_) => callbacks['onRelease']!(),
              onTapCancel: () => callbacks['onRelease']!(),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: colorScheme.secondary.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
