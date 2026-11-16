import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/router.dart';

// П. 77: вкладка «натягивается» — переход, только если при отпускании натянули
// дальше трети экрана и вели вбок. Скорость не важна.
void main() {
  const width = 360.0;

  test('натянул дальше точки вбок — переход', () {
    expect(tabPullCommits(const Offset(-130, 20), width), isTrue);
    expect(tabPullCommits(const Offset(120, -10), width), isTrue);
  });

  test('не дотянул — пружинит обратно', () {
    expect(tabPullCommits(const Offset(-80, 0), width), isFalse);
  });

  test('наискось вниз — не переход, даже далеко', () {
    expect(tabPullCommits(const Offset(-150, 100), width), isFalse);
  });
}
