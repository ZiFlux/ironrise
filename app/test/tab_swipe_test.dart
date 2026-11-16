import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/router.dart';

// П. 77: вкладки листаются только решительным горизонтальным свайпом.
void main() {
  test('быстрый горизонтальный свайп — листает', () {
    expect(
      isTabSwipe(const Offset(-150, 20), const Offset(-1200, 100)),
      isTrue,
    );
    expect(isTabSwipe(const Offset(120, -10), const Offset(900, 0)), isTrue);
  });

  test('наискось вниз — не листает', () {
    expect(
      isTabSwipe(const Offset(-120, 90), const Offset(-1000, 800)),
      isFalse,
    );
  });

  test('короткий или медленный — не листает', () {
    expect(isTabSwipe(const Offset(-50, 0), const Offset(-2000, 0)), isFalse);
    expect(isTabSwipe(const Offset(-200, 0), const Offset(-300, 0)), isFalse);
  });

  test('палец туда, бросок обратно — не листает', () {
    expect(isTabSwipe(const Offset(-150, 0), const Offset(900, 0)), isFalse);
  });
}
