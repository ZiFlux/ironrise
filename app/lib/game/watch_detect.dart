/// Распознать марку часов по имени Bluetooth-устройства или узла Wear OS
/// и по установленным приложениям-компаньонам (п. 152: мастер подключения).
/// Чистая логика — без платформы, проверяется тестами.
library;

/// Найденное устройство: что это и как получить с него пульс.
class DetectedWatch {
  const DetectedWatch({
    required this.name,
    required this.guideId,
    this.address,
    this.wearNode,
  });

  /// Как устройство называет себя: «Galaxy Watch5 (A1B2)».
  final String name;

  /// Ключ инструкции в watch_guides.dart: wearos, huawei, garmin…
  final String guideId;

  /// Bluetooth-адрес сопряжённого устройства — для подключения без поиска.
  final String? address;

  /// Узел Wear OS — для установки IronRise на часы.
  final String? wearNode;

  bool get isWearOs => guideId == 'wearos';
}

/// Подстроки имени → марка. Порядок важен: «Honor Band» раньше общего «band».
const _patterns = <(String, List<String>)>[
  ('wearos', ['galaxy watch', 'pixel watch', 'ticwatch', 'wear os']),
  ('huawei', ['huawei', 'honor', 'watch gt', 'watch fit', 'watch d']),
  (
    'garmin',
    [
      'garmin',
      'forerunner',
      'fenix',
      'fēnix',
      'venu',
      'vivoactive',
      'instinct',
      'epix',
      'hrm-',
    ],
  ),
  ('polar', ['polar']),
  ('coros', ['coros']),
  (
    'amazfit',
    ['amazfit', 'gtr', 'gts', 't-rex', 'zepp', 'bip ', 'active edge'],
  ),
  (
    'xiaomi',
    ['xiaomi', 'redmi', 'mi smart band', 'mi band', 'smart band', 'mi watch'],
  ),
];

/// Приложения-компаньоны часов (те же пакеты — в <queries> манифеста).
const companionApps = <String, String>{
  'com.samsung.android.app.watchmanager': 'wearos',
  'com.huawei.health': 'huawei',
  'com.garmin.android.apps.connectmobile': 'garmin',
  'fi.polar.polarflow': 'polar',
  'com.huami.watch.hmwatchmanager': 'amazfit',
  'com.xiaomi.wearable': 'xiaomi',
  'com.xiaomi.hm.health': 'xiaomi',
};

/// Марка по имени устройства; null — это не часы (наушники, машина, колонка).
String? guideIdForName(String name) {
  final n = name.toLowerCase();
  for (final (id, words) in _patterns) {
    if (words.any(n.contains)) return id;
  }
  return null;
}

/// Свести всё найденное в список часов без повторов: узлы Wear OS,
/// сопряжённые устройства по имени. Марки только из компаньонов (часы сейчас
/// не рядом) — отдельным списком: подсказать инструкцию, но не «нашли часы».
({List<DetectedWatch> watches, Set<String> brandsByApp}) detectWatches({
  required List<({String id, String name})> wearNodes,
  required List<({String name, String address})> bonded,
  required List<String> installedCompanions,
}) {
  final watches = <DetectedWatch>[
    for (final node in wearNodes)
      DetectedWatch(name: node.name, guideId: 'wearos', wearNode: node.id),
  ];
  final wearNames = wearNodes.map((n) => n.name.toLowerCase()).toSet();
  for (final d in bonded) {
    final id = guideIdForName(d.name);
    if (id == null) continue;
    // Часы Wear OS уже есть узлом — второй раз из списка Bluetooth не берём.
    if (id == 'wearos' && wearNodes.isNotEmpty) continue;
    if (wearNames.contains(d.name.toLowerCase())) continue;
    watches.add(DetectedWatch(name: d.name, guideId: id, address: d.address));
  }
  final found = watches.map((w) => w.guideId).toSet();
  final byApp = {
    for (final pkg in installedCompanions)
      if (companionApps[pkg] case final id? when !found.contains(id)) id,
  };
  return (watches: watches, brandsByApp: byApp);
}
