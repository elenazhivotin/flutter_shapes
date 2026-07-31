import 'package:flutter/material.dart';
import 'dart:math';

// 🫧 BUBBLE ANIMATION WIDGET

class BubbleAnimationWidget extends StatelessWidget {
  final Animation<double> animation;

  const BubbleAnimationWidget({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          children: List.generate(11, (index) {
            final random = Random(index);
            final delay = index * 0.1;
            final animationValue = (animation.value - delay).clamp(0.0, 1.0);

            final bubbleSize = 30.0 + random.nextDouble() * 30.0;
            final horizontalOffset = random.nextDouble() * 550.0 - 150.0;
            final verticalOffset = 600.0 - (animationValue * 700.0);
            final opacity = (animationValue < 0.1)
                ? animationValue * 10
                : (animationValue > 0.9)
                    ? (1 - animationValue) * 10
                    : 1.0;

            return Positioned(
              left: 200.0 + horizontalOffset,
              top: verticalOffset,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: bubbleSize,
                  height: bubbleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(
                      (random.nextInt(256) << 16) |
                      (random.nextInt(256) << 8) |
                      random.nextInt(256),
                    ).withOpacity(0.7),
                    border: Border.all(
                      color: Colors.white,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}