import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/watch_detect.dart';
import 'package:ironrise/game/watch_guides.dart';

void main() {
  test('марка по имени устройства', () {
    expect(guideIdForName('Galaxy Watch5 (A1B2)'), 'wearos');
    expect(guideIdForName('HUAWEI WATCH GT 4-1A2'), 'huawei');
    expect(guideIdForName('Forerunner 265'), 'garmin');
    expect(guideIdForName('Polar Ignite 3 B1C2D3E4'), 'polar');
    expect(guideIdForName('COROS PACE 3'), 'coros');
    expect(guideIdForName('Amazfit GTR 4'), 'amazfit');
    expect(guideIdForName('Xiaomi Smart Band 8 1A2B'), 'xiaomi');
    expect(guideIdForName('JBL Tune 510BT'), isNull);
    expect(guideIdForName('Kia Sportage'), isNull);
  });

  test('у каждой марки есть инструкция', () {
    for (final id in [...companionApps.values, 'strap']) {
      expect(watchGuideById(id), isNotNull, reason: id);
    }
  });

  test(
    'часы Wear OS не дублируются из списка Bluetooth, наушники отброшены',
    () {
      final r = detectWatches(
        wearNodes: [(id: 'n1', name: 'Galaxy Watch5 (A1B2)')],
        bonded: [
          (name: 'Galaxy Watch5 (A1B2)', address: 'AA'),
          (name: 'Galaxy Buds2', address: 'BB'),
          (name: 'Amazfit GTR 4', address: 'CC'),
        ],
        installedCompanions: [
          'com.samsung.android.app.watchmanager',
          'com.garmin.android.apps.connectmobile',
        ],
      );
      expect(r.watches.map((w) => w.guideId), ['wearos', 'amazfit']);
      expect(r.watches.first.wearNode, 'n1');
      expect(r.watches.last.address, 'CC');
      // Garmin Connect стоит, а часов не видно — только подсказка.
      expect(r.brandsByApp, {'garmin'});
    },
  );
}
