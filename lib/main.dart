import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_shapes/contourGenerator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ShapeCanvasPage(),
    );
  }
}

// ---------------- MODEL ----------------

enum ShapeType { circle, square, triangle, invertedTriangle, rightTriangle, leftTriangle, topLeftTriangle, topRightTriangle }

class ShapeItem {
  ShapeType type;
  Offset position;

  ShapeItem({required this.type, required this.position});
}

Offset snapShapePositionToContour(
  Offset position,
  List<PlacedShape>? contourShapes, {
  double shapeSize = 90.0,
  double snapDistance = 5.0,
  Contour? contour,
}) {
  if (contourShapes == null || contourShapes.isEmpty) {
    if (contour == null || !contour.isClosed || contour.points.length < 3) {
      return position;
    }
  }

  final shapeRect = Rect.fromLTWH(position.dx, position.dy, shapeSize, shapeSize);
  double bestDistance = double.infinity;
  Offset snappedPosition = position;

  if (contour != null && contour.isClosed && contour.points.length >= 3) {
    final contourPoints = contour.points;
    for (int i = 0; i < contourPoints.length; i++) {
      final a = contourPoints[i];
      final b = contourPoints[(i + 1) % contourPoints.length];
      final edge = b - a;
      final edgeLength = edge.distance;

      if (edgeLength == 0) {
        continue;
      }

      final t = ((shapeRect.center.dx - a.dx) * edge.dx + (shapeRect.center.dy - a.dy) * edge.dy) /
          (edgeLength * edgeLength);
      final clampedT = t.clamp(0.0, 1.0);
      final projection = a + edge * clampedT;
      final distance = (shapeRect.center - projection).distance;

      if (distance <= snapDistance) {
        final dx = projection.dx - shapeRect.center.dx;
        final dy = projection.dy - shapeRect.center.dy;

        final snapped = Offset(position.dx + dx, position.dy + dy);
        if (distance < bestDistance) {
          bestDistance = distance;
          snappedPosition = snapped;
        }
      }
    }
  }

  if (contourShapes != null && contourShapes.isNotEmpty) {
    for (final contourShape in contourShapes) {
      final contourRect = Rect.fromLTWH(
        contourShape.gridX * shapeSize,
        contourShape.gridY * shapeSize,
        shapeSize,
        shapeSize,
      );

      // Calculate distances to each edge
      final distLeft = (shapeRect.right - contourRect.left).abs();
      final distRight = (shapeRect.left - contourRect.right).abs();
      final distTop = (shapeRect.bottom - contourRect.top).abs();
      final distBottom = (shapeRect.top - contourRect.bottom).abs();

      // Define all possible snap positions (edges and corners)
      final snapPositions = [
        // Corners (both axes change) - prioritize these
        (
          distance: sqrt(distLeft * distLeft + distTop * distTop),
          position: Offset(contourRect.left - shapeSize, contourRect.top - shapeSize),
          name: 'top-left corner',
        ),
        (
          distance: sqrt(distRight * distRight + distTop * distTop),
          position: Offset(contourRect.right, contourRect.top - shapeSize),
          name: 'top-right corner',
        ),
        (
          distance: sqrt(distLeft * distLeft + distBottom * distBottom),
          position: Offset(contourRect.left - shapeSize, contourRect.bottom),
          name: 'bottom-left corner',
        ),
        (
          distance: sqrt(distRight * distRight + distBottom * distBottom),
          position: Offset(contourRect.right, contourRect.bottom),
          name: 'bottom-right corner',
        ),
        // Edges (single axis change)
        (
          distance: distLeft,
          position: Offset(contourRect.left - shapeSize, shapeRect.top),
          name: 'left edge',
        ),
        (
          distance: distRight,
          position: Offset(contourRect.right, shapeRect.top),
          name: 'right edge',
        ),
        (
          distance: distTop,
          position: Offset(shapeRect.left, contourRect.top - shapeSize),
          name: 'top edge',
        ),
        (
          distance: distBottom,
          position: Offset(shapeRect.left, contourRect.bottom),
          name: 'bottom edge',
        ),
      ];

      for (final snap in snapPositions) {
        if (snap.distance <= snapDistance && snap.distance < bestDistance) {
          bestDistance = snap.distance;
          snappedPosition = snap.position;
        }
      }
    }
  }

  if (bestDistance <= snapDistance) {
    debugPrint(
      'Contour snapped: from (${position.dx.toStringAsFixed(1)}, ${position.dy.toStringAsFixed(1)}) '
      'to (${snappedPosition.dx.toStringAsFixed(1)}, ${snappedPosition.dy.toStringAsFixed(1)})',
    );
  }

  return snappedPosition;
}

// ---------------- PAGE ----------------

class ShapeCanvasPage extends StatefulWidget {
  const ShapeCanvasPage({super.key});

  @override
  State<ShapeCanvasPage> createState() => _ShapeCanvasPageState();
}

class _ShapeCanvasPageState extends State<ShapeCanvasPage> {
  final List<ShapeItem> shapes = [];
  List<PlacedShape>? contourShapes;  // For LevelContourPainter

  Contour? contour;
  bool isDrawing = false;
  String statusText = "Tap on the canvas to add contour points. Double tap to close the contour.";

  bool isInsideContour(Offset point) {
    if (contour == null || !contour!.isClosed) return true;

    return contour!.containsPoint(point);
  }

  Offset _nextShapePosition() {
    if (contour != null && contour!.isClosed) {
      final candidates = <Offset>[
        Offset(contour!.boundingBox.left + 40, contour!.boundingBox.top + 40),
        Offset(contour!.boundingBox.center.dx, contour!.boundingBox.top + 60),
        Offset(contour!.boundingBox.left + 60, contour!.boundingBox.center.dy),
        Offset(contour!.boundingBox.center.dx, contour!.boundingBox.center.dy),
      ];

      for (final candidate in candidates) {
        if (contour!.containsPoint(candidate)) {
          return candidate;
        }
      }
    }

    return Offset(60 + shapes.length * 18, 110 + (shapes.length % 4) * 18);
  }

  void addShape(ShapeType type) {
    final position = _nextShapePosition();

    setState(() {
      shapes.add(
        ShapeItem(type: type, position: position),
      );
    });
  }

  void startContourDrawing() {
    setState(() {
      isDrawing = true;
      contour = Contour(points: []);
      statusText = 'Contour drawing active';
    });
  }

  void addContourPoint(Offset point) {
    if (!isDrawing || contour == null) return;

    setState(() {
      contour!.points.add(point);
      statusText = contour!.points.length == 1
          ? 'Contour point added. Tap again to continue.'
          : 'Contour point added';
    });
  }

  void closeContour() {
    if (contour == null || contour!.points.length < 3) return;

    setState(() {
      contour!.isClosed = true;
      isDrawing = false;
      statusText = 'Contour closed. Add shapes inside it.';
    });
  }

  void clearCanvas() {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Clear canvas?"),
      content: const Text("This will remove all shapes and contour."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            setState(() {
              shapes.clear();
              contourShapes = null;
              contour = null;
              isDrawing = false;
              statusText = 'Canvas cleared';
            });
          },
          child: const Text("Clear"),
        ),
      ],
    ),
  );
  }

  void addCountourTemplate() {
    final generator = ContourGenerator();
    final randomCount = Random().nextInt(6) + 5;  // Random between 5-10
    final randomShapes = generator.generateLevel(randomCount);
    
    setState(() {
      shapes.clear();
      contourShapes = randomShapes;  // Use LevelContourPainter to paint these as contour
      contour = null;
      isDrawing = false;
      statusText = 'Random contour generated using LevelContourPainter';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Canvas Shapes")),
      body: Column(
        children: [
          // 🔝 TOP TOOLBAR
          Container(
            height: 80,
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              // children: [
              //   shapeButton(Icons.circle, () => addShape(ShapeType.circle)),
              //   shapeButton(Icons.crop_square, () => addShape(ShapeType.square)),
              //   shapeButton(Icons.change_history,
              //       () => addShape(ShapeType.triangle)),
              //   shapeButton(Icons.south_east,
              //       () => addShape(ShapeType.rightTriangle)),

              // ],
              children: [
  // Стандартные фигуры через иконки
  shapeButton(
    const Icon(Icons.circle, size: 28), 
    () => addShape(ShapeType.circle),
  ),
  shapeButton(
    const Icon(Icons.crop_square, size: 28), 
    () => addShape(ShapeType.square),
  ),
  shapeButton(
    const Icon(Icons.change_history, size: 28), 
    () => addShape(ShapeType.triangle),
  ),

  shapeButton(
    CustomPaint(
      size: const Size(24, 24),
      painter: InvertedTrianglePainter(
        fillColor: Colors.transparent,
        strokeColor: Colors.black,
        strokeWidth: 2.0,
      ),
    ),
    () => addShape(ShapeType.invertedTriangle),
  ),
  
  shapeButton(
    CustomPaint(
      size: const Size(24, 24),
      painter: UniversalTrianglePainter(
        orientation: TriangleOrientation.bottomLeft,
        fillColor: Colors.transparent, // Прозрачный внутри, как иконка
        strokeColor: Colors.black,     // Цвет контура иконки
        strokeWidth: 2.0,
      ),
    ),
    () => addShape(ShapeType.leftTriangle),
  ),
  
   shapeButton(
    CustomPaint(
      size: const Size(24, 24),
      painter: UniversalTrianglePainter(
        orientation: TriangleOrientation.bottomRight,
        fillColor: Colors.transparent, 
        strokeColor: Colors.black,     
        strokeWidth: 2.0,
      ),
    ),
    () => addShape(ShapeType.rightTriangle),
  ),

  shapeButton(
    CustomPaint(
      size: const Size(24, 24),
      painter: UniversalTrianglePainter(
        orientation: TriangleOrientation.topRight,
        fillColor: Colors.transparent, 
        strokeColor: Colors.black,     
        strokeWidth: 2.0,
      ),
    ),
    () => addShape(ShapeType.topRightTriangle),
  ),

  shapeButton(
    CustomPaint(
      size: const Size(24, 24),
      painter: UniversalTrianglePainter(
        orientation: TriangleOrientation.topLeft,
        fillColor: Colors.transparent, 
        strokeColor: Colors.black,     
        strokeWidth: 2.0,
      ),
    ),
    () => addShape(ShapeType.topLeftTriangle),
  ),
],
            ),
          ),
          Row(children: [
            ElevatedButton(
              onPressed: startContourDrawing,
              child: Text(isDrawing ? 'Contour Drawing' : 'Draw Contour'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: clearCanvas,
              child: const Text("Clear"),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: addCountourTemplate,
              child: const Text("Draw Template"),
            ),
          ],),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              statusText,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          

          // 🎨 CANVAS
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                addContourPoint(details.localPosition);
              },
              onDoubleTap: () {
                closeContour();
              },
              child: Stack(
                children: [
                  // ✅ DRAW CONTOUR using LevelContourPainter (if using template)
                  if (contourShapes != null)
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: LevelContourPainter(contourShapes!),
                      ),
                    ),

                  // ✅ DRAW CONTOUR (if using old manual system)
                  if (contour != null && contourShapes == null)
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: ContourPainter(contour!),
                      ),
                    ),

                  // 👇 shapes interactive
                  ...shapes.map((shape) {
                    return DraggableShape(
                      shape: shape,
                      contourShapes: contourShapes,
                      contour: contour,
                      onDrag: (offset) {
                        setState(() {
                          shape.position = offset;
                        });
                      },
                      isInsideContour: isInsideContour,
                    );
                  }),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // Widget shapeButton(IconData icon, VoidCallback onTap) {
  //   return GestureDetector(
  //     onTap: onTap,
  //     child: Icon(icon, size: 40),
  //   );
  // }

  Widget shapeButton(Widget iconWidget, VoidCallback onTap) {
    return IconButton(
      icon: iconWidget,
      onPressed: onTap,
    );
  }

}

// ---------------- DRAGGABLE SHAPE ----------------

class DraggableShape extends StatefulWidget {
  final ShapeItem shape;
  final Function(Offset) onDrag;
  final bool Function(Offset) isInsideContour;
  final List<PlacedShape>? contourShapes;
  final Contour? contour;

  const DraggableShape({
    super.key,
    required this.shape,
    required this.onDrag,
    required this.isInsideContour,
    this.contourShapes,
    this.contour,
  });

  @override
  State<DraggableShape> createState() => _DraggableShapeState();
}

class _DraggableShapeState extends State<DraggableShape> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.shape.position.dx,
      top: widget.shape.position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          final newOffset = Offset(
            widget.shape.position.dx + details.delta.dx,
            widget.shape.position.dy + details.delta.dy,
          );

          final snappedOffset = snapShapePositionToContour(
            newOffset,
            widget.contourShapes,
            contour: widget.contour,
          );

          final shouldApplySnap = snappedOffset != newOffset || widget.isInsideContour(snappedOffset);

          if (shouldApplySnap) {
            if (snappedOffset != newOffset) {
              debugPrint(
                'Applying snapped position: ${snappedOffset.dx.toStringAsFixed(1)}, ${snappedOffset.dy.toStringAsFixed(1)}',
              );
            }
            widget.onDrag(snappedOffset);
          }
        },
        child: buildShape(widget.shape.type),
      ),
    );
  }

  Widget buildShape(ShapeType type) {
    const double strokeWidth = 2.0;
    const Color strokeColor = Colors.black;

    switch (type) {
      case ShapeType.circle:
        return Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            // add border
            border: Border.fromBorderSide(
              BorderSide(color: strokeColor, width: strokeWidth),
            ),
          ),        
        );

      case ShapeType.square:
        return Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(
            color: Colors.red,
            border: Border.fromBorderSide(
              BorderSide(color: strokeColor, width: strokeWidth),
            ),
          ),       
        );

      case ShapeType.triangle:
        return CustomPaint(
          size: const Size(90, 90),
          painter: TrianglePainter(),
        );

      case ShapeType.invertedTriangle:
        return CustomPaint(
          size: const Size(90, 90),
          painter: InvertedTrianglePainter(),
        );

      case ShapeType.rightTriangle:
        return CustomPaint(
          size: const Size(90, 90),
          painter: UniversalTrianglePainter(
            orientation: TriangleOrientation.bottomRight,
            fillColor: Colors.yellow,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
          ),
      );

      case ShapeType.leftTriangle:
        return CustomPaint(
        size: const Size(90, 90),
        painter: UniversalTrianglePainter(
          orientation: TriangleOrientation.bottomLeft,
          fillColor: Colors.orange,
          strokeColor: strokeColor,
          strokeWidth: strokeWidth,
        ),
      );

      case ShapeType.topLeftTriangle:
        return CustomPaint(
        size: const Size(90, 90),
        painter: UniversalTrianglePainter(
          orientation: TriangleOrientation.topLeft,
          fillColor: Colors.purple,
          strokeColor: strokeColor,
          strokeWidth: strokeWidth,
        ),
      );

      case ShapeType.topRightTriangle:
        return CustomPaint(
        size: const Size(90, 90),
        painter: UniversalTrianglePainter(
          orientation: TriangleOrientation.topRight,
          fillColor: Colors.grey,
          strokeColor: strokeColor,
          strokeWidth: strokeWidth,
        ),
      );
    }
  }
}

// 🔺 TRIANGLE PAINTER

class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.green;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);

    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class InvertedTrianglePainter extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  InvertedTrianglePainter({
    this.fillColor = Colors.cyan,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = fillColor;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RightTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class UniversalTrianglePainter extends CustomPainter {
  final TriangleOrientation orientation;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  UniversalTrianglePainter({
    required this.orientation,
    this.fillColor = Colors.yellow,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();

    // pathes for all 4 oprtions of triangle orientation
    switch (orientation) {
      case TriangleOrientation.topLeft: // (◤)
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(0, size.height)
          ..close();
        break;

      case TriangleOrientation.bottomLeft: // (◣)
        path
          ..moveTo(0, 0)
          ..lineTo(0, size.height)
          ..lineTo(size.width, size.height)
          ..close();
        break;

      case TriangleOrientation.topRight: // (◥)
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..close();
        break;

      case TriangleOrientation.bottomRight: // (◢)
        path
          ..moveTo(0, size.height)
          ..lineTo(size.width, size.height)
          ..lineTo(size.width, 0)
          ..close();
        break;
    }

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
      //..strokeJoin = StrokeJoin.round; // Сглаживает острые углы контура

    canvas.drawPath(path, strokePaint);
  }

  // only if any of the properties change, we need to repaint
  @override
  bool shouldRepaint(covariant UniversalTrianglePainter oldDelegate) {
    return oldDelegate.orientation != orientation ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class Contour {
  final List<Offset> points;
  bool isClosed;

  Contour({required this.points, this.isClosed = false});

  Rect get boundingBox {
    if (points.isEmpty) {
      return Rect.fromLTWH(0, 0, 0, 0);
    }

    final left = points.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final top = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final right = points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final bottom = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

    return Rect.fromLTRB(left, top, right, bottom);
  }

  bool containsPoint(Offset point) {
    if (!isClosed || points.length < 3) return true;

    int intersections = 0;

    for (int i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];

      if (((a.dy > point.dy) != (b.dy > point.dy)) &&
          (point.dx <
              (b.dx - a.dx) *
                      (point.dy - a.dy) /
                      (b.dy - a.dy) +
                  a.dx)) {
        intersections++;
      }
    }

    return intersections % 2 == 1;
  }
}

class ContourPainter extends CustomPainter {
  final Contour contour;

  ContourPainter(this.contour);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final path = Path();

    if (contour.points.isEmpty) return;

    path.moveTo(contour.points.first.dx, contour.points.first.dy);

    for (var p in contour.points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    if (contour.isClosed) {
      path.close();
      canvas.drawPath(path, fillPaint);
    }

    canvas.drawPath(path, paint);

    // draw points
    for (var p in contour.points) {
      canvas.drawCircle(p, 4, Paint()..color = Colors.red);
    }
    
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

enum TriangleOrientation {
  topLeft,
  bottomLeft,
  topRight,
  bottomRight,
}

