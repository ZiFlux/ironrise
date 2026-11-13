import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/widgets/format.dart';

void main() {
  test('тысячи через узкий пробел', () {
    expect(formatThousands(0), '0');
    expect(formatThousands(999), '999');
    expect(formatThousands(8432), '8\u202F432');
    expect(formatThousands(1234567), '1\u202F234\u202F567');
  });

  test('склонение «подход»', () {
    expect([1, 2, 5, 11, 12, 21, 22, 25].map(setsWord), [
      'подход',
      'подхода',
      'подходов',
      'подходов',
      'подходов',
      'подход',
      'подхода',
      'подходов',
    ]);
  });
}
