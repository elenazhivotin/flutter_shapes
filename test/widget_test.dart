import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_shapes/main.dart';

void main() {
  test('right triangle shape is available', () {
    expect(ShapeType.values.contains(ShapeType.rightTriangle), isTrue);
  });

  test('closed contour reports whether a point is inside', () {
    final contour = Contour(
      points: const [
        Offset(100, 100),
        Offset(250, 100),
        Offset(250, 250),
        Offset(100, 250),
      ],
      isClosed: true,
    );

    expect(contour.containsPoint(const Offset(150, 150)), isTrue);
    expect(contour.containsPoint(const Offset(50, 50)), isFalse);
  });

  testWidgets('Draw Contour enters drawing mode', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Draw Contour'), findsOneWidget);
    await tester.tap(find.text('Draw Contour'));
    await tester.pump();

    expect(find.text('Contour drawing active'), findsOneWidget);
  });
}
