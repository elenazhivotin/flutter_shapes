import 'package:flutter/material.dart';
import 'dart:math';

import 'package:flutter_shapes/main.dart';

class PlacedShape {
  final ShapeType type;
  final int gridX; // Позиция по Х в сетке (0, 1, 2...)
  final int gridY; // Позиция по Y в сетке (0, 1, 2...)
  final TriangleOrientation? orientation; // Для прямоугольных треугольников

  PlacedShape({
    required this.type,
    required this.gridX,
    required this.gridY,
    this.orientation,
  });

  // Перевод координат сетки в пиксели с учётом экранного смещения
  Offset getOffset(double size, {double originX = 0.0, double originY = 0.0}) =>
      Offset(originX + gridX * size, originY + gridY * size);
}

double calculateResponsiveShapeSize(
  Size canvasSize, {
  double minSize = 58.0,
  double maxSize = 90.0,
  double sidePadding = 48.0,
  int maxColumns = 4,
}) {
  if (canvasSize.width <= 0) {
    return maxSize;
  }

  final availableWidth = canvasSize.width - sidePadding;
  final candidate = availableWidth / maxColumns;
  return candidate.clamp(minSize, maxSize);
}

Offset calculateContourOrigin(
  Size canvasSize, {
  required double shapeSize,
  double leftPadding = 10.0,
  double topPadding = 0.0,
  int columns = 4,
}) {
  final left = leftPadding;
  final top = (1.5 * shapeSize) + topPadding;

  final maxLeft = max(0.0, canvasSize.width - (columns * shapeSize) - leftPadding);
  return Offset(left.clamp(0.0, maxLeft), top);
}

class ContourGenerator {
  final double shapeSize;
  final Random _random = Random();

  ContourGenerator({double? shapeSize}) : shapeSize = shapeSize ?? 90.0;

  // Генерирует массив фигур, которые гарантированно стоят на сетке shapeSize x shapeSize
  List<PlacedShape> generateLevel(int numberOfShapes) {
    List<PlacedShape> placedShapes = [];
    
    // Множество занятых ячеек сетки, чтобы фигуры не накладывались
    Set<String> occupiedCells = {};

    // 1. Создаем первую базовую фигуру в верхнем левом углу
    int currentX = 2;
    int currentY = 1;
    placedShapes.add(PlacedShape(type: ShapeType.square, gridX: currentX, gridY: currentY));
    occupiedCells.add("$currentX,$currentY");

    // 2. Достраиваем остальные фигуры только вправо и вниз
    for (int i = 1; i < numberOfShapes; i++) {
      // Ищем случайную уже выставленную фигуру, чтобы прикрепиться к ней
      var baseShape = placedShapes[_random.nextInt(placedShapes.length)];
      
      // Выбираем случайное направление только вправо и вниз
      int dirX = 0;
      int dirY = 0;
      int direction = _random.nextInt(2);  // Only 0 (right) or 1 (down)
      if (direction == 0) dirX = 1;      // Вправо
      else if (direction == 1) dirY = 1; // Вниз

      int nextX = baseShape.gridX + dirX;
      int nextY = baseShape.gridY + dirY;

      // Проверяем, свободна ли ячейка
      if (!occupiedCells.contains("$nextX,$nextY")) {
        // Выбираем случайный тип фигуры
        ShapeType randomType = ShapeType.values[_random.nextInt(ShapeType.values.length)];
        
        TriangleOrientation? orientation;
        if (randomType == ShapeType.rightTriangle || randomType == ShapeType.leftTriangle) {
          orientation = _random.nextBool() ? TriangleOrientation.topLeft : TriangleOrientation.bottomRight;
        }

        placedShapes.add(PlacedShape(
          type: randomType,
          gridX: nextX,
          gridY: nextY,
          orientation: orientation,
        ));
        occupiedCells.add("$nextX,$nextY");
      } else {
        // Если ячейка занята, повторяем итерацию цикла
        i--;
      }
    }

    return placedShapes;
  }
}

class LevelContourPainter extends CustomPainter {
  final List<PlacedShape> shapes;
  final double shapeSize;
  final Offset origin;

  LevelContourPainter(this.shapes, {this.shapeSize = 90.0, this.origin = Offset.zero});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final strokePaint = Paint()
      ..color = Colors.black45 // Серый цвет контура-подсказки
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final effectiveOrigin = origin == Offset.zero ? calculateContourOrigin(canvasSize, shapeSize: shapeSize) : origin;

    for (var shape in shapes) {
      // Получаем пиксельные координаты левого верхнего угла ячейки
      Offset offset = shape.getOffset(shapeSize, originX: effectiveOrigin.dx, originY: effectiveOrigin.dy);
      
      canvas.save();
      // Сдвигаем холст в нужную точку сетки
      canvas.translate(offset.dx, offset.dy);

      final path = Path();

      switch (shape.type) {
        case ShapeType.circle:
          // Контур круга
          canvas.drawCircle(Offset(shapeSize / 2, shapeSize / 2), shapeSize / 2, strokePaint);
          break;

        case ShapeType.square:
          // Контур квадрата
          Rect rect = Rect.fromLTWH(0, 0, shapeSize, shapeSize);
          canvas.drawRect(rect, strokePaint);
          break;

        case ShapeType.triangle:
          // Обычный равнобедренный треугольник
          path.moveTo(shapeSize / 2, 0);
          path.lineTo(shapeSize, shapeSize);
          path.lineTo(0, shapeSize);
          path.close();
          canvas.drawPath(path, strokePaint);
          break;

        case ShapeType.invertedTriangle:
          // Перевернутый равнобедренный треугольник
          path.moveTo(shapeSize / 2, shapeSize);
          path.lineTo(0, 0);
          path.lineTo(shapeSize, 0);
          path.close();
          canvas.drawPath(path, strokePaint);
          break;

        case ShapeType.rightTriangle:
        case ShapeType.leftTriangle:
        case ShapeType.topLeftTriangle:
        case ShapeType.topRightTriangle:
          // Прямоугольные треугольники
          if (shape.orientation == TriangleOrientation.bottomLeft) {
            path.moveTo(0, 0);
            path.lineTo(shapeSize, 0);
            path.lineTo(0, shapeSize);
          } else if (shape.orientation == TriangleOrientation.topLeft) {
            path.moveTo(0, 0);
            path.lineTo(0, shapeSize);
            path.lineTo(shapeSize, shapeSize);
          } else if (shape.orientation == TriangleOrientation.bottomRight) {
            path.moveTo(0, 0);
            path.lineTo(shapeSize, 0);
            path.lineTo(shapeSize, shapeSize);
          } else {
            path.moveTo(0, shapeSize);
            path.lineTo(shapeSize, shapeSize);
            path.lineTo(shapeSize, 0);
          }
          path.close();
          canvas.drawPath(path, strokePaint);
          break;
      }

      canvas.restore(); // Возвращаем холст в исходное состояние для следующей фигуры
    }
  }

  @override
  bool shouldRepaint(covariant LevelContourPainter oldDelegate) => oldDelegate.shapes != shapes;
}

class GameBoard extends StatefulWidget {
  const GameBoard({Key? key}) : super(key: key);

  @override
  State<GameBoard> createState() => _GameBoardState();
}



class _GameBoardState extends State<GameBoard> {
  List<PlacedShape> currentLevel = [];

  @override
  void initState() {
    super.initState();
    // Генерируем уровень, например, из 5 соединенных фигур
    currentLevel = ContourGenerator().generateLevel(15);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Генератор Контуров")),
      body: Center(
        child: Container(
          width: 500,
          height: 500,
          color: Colors.grey[100],
          child: CustomPaint(
            painter: LevelContourPainter(currentLevel),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            // Перегенерировать уровень при нажатии кнопки
            currentLevel = ContourGenerator().generateLevel(15);
          });
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
