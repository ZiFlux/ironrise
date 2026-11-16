import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/widgets/line_chart.dart';

// П. 105: линейный график — рисуется, нажатие выбирает точку.
void main() {
  testWidgets('кривая с подсказкой по нажатию', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: LineChart(
              color: Colors.green,
              points: [
                for (var i = 0; i < 5; i++)
                  (label: '$i.11', value: 60.0 + i, tip: 'точка $i'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('точка 4'), findsOneWidget);
    await t.tapAt(t.getTopLeft(find.byType(CustomPaint).last) + const Offset(2, 40));
    await t.pump();
    expect(find.text('точка 0'), findsOneWidget);
  });

  testWidgets('одна точка и ровная линия — без ошибок', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LineChart(
            color: Colors.green,
            points: const [(label: '1.11', value: 70, tip: 'одна')],
          ),
        ),
      ),
    );
    expect(find.text('одна'), findsOneWidget);
  });
}
