import 'package:flutter/material.dart';

class ClassicJoystick extends StatelessWidget {
  final Map<String, Function> callbacks;

  const ClassicJoystick({super.key, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            colorScheme.primary.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDirectionButton('↑', callbacks['onForward']!, colorScheme),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDirectionButton('←', callbacks['onLeft']!, colorScheme),
              const SizedBox(width: 60),
              _buildDirectionButton('→', callbacks['onRight']!, colorScheme),
            ],
          ),
          _buildDirectionButton('↓', callbacks['onBackward']!, colorScheme),
        ],
      ),
    );
  }

  Widget _buildDirectionButton(String label, Function onPressed, ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.95),
      duration: const Duration(milliseconds: 100),
      builder: (context, scale, child) {
        return GestureDetector(
          onTapDown: (_) => onPressed(),
          onTapUp: (_) => callbacks['onRelease']!(),
          onTapCancel: () => callbacks['onRelease']!(),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
