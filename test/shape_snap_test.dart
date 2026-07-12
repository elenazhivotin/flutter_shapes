import 'package:flutter/material.dart';
import 'package:flutter_shapes/contourGenerator.dart';
import 'package:flutter_shapes/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shape contour snapping', () {
    test('snaps to the nearest contour side when within 3px', () {
      final contourShapes = [
        PlacedShape(type: ShapeType.square, gridX: 1, gridY: 1),
      ];

      final snapped = snapShapePositionToContour(
        const Offset(177, 120),
        contourShapes,
      );

      expect(snapped.dx, 180);
      expect(snapped.dy, 120);
    });

    test('snaps to a hand-drawn contour edge when within 3px', () {
      final contour = Contour(
        points: [
          const Offset(100, 100),
          const Offset(300, 100),
          const Offset(300, 300),
          const Offset(100, 300),
        ],
        isClosed: true,
      );

      final snapped = snapShapePositionToContour(
        const Offset(297, 120),
        null,
        contour: contour,
      );

      expect(snapped.dx, 297);
      expect(snapped.dy, 120);
    });
  });
}
