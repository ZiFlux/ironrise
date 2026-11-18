/// Как подключить часы без приложения IronRise на них (п. 125 бэклога):
/// трансляция пульса по Bluetooth или Health Connect. Пути меню — по официальным
/// инструкциям производителей (16.11.2026); у моделей и прошивок они могут отличаться.
typedef WatchGuide = ({
  /// Ключ марки для мастера подключения (watch_detect.dart).
  String id,
  String brand,
  String models,

  /// Пульс идёт живьём по Bluetooth (иначе — только через Health Connect).
  bool live,
  List<String> steps,

  /// Проверено на реальном устройстве игроком или разработчиком.
  bool tested,
});

const watchGuides = <WatchGuide>[
  (
    id: 'huawei',
    brand: 'Huawei, Honor',
    models: 'Watch GT, Watch Fit, Band',
    live: true,
    tested: true,
    steps: [
      'На часах: Настройки → «Трансляция данных о пульсе» (HR Data Broadcasts)',
      'Прочитайте условия и подтвердите галочкой',
      'Начните на часах любую тренировку — с этого момента пульс транслируется',
      'В IronRise нажмите «Найти датчик» и выберите часы',
      'Закончить трансляцию: боковая кнопка → галочка',
    ],
  ),
  (
    id: 'garmin',
    brand: 'Garmin',
    models: 'Forerunner, Venu, fēnix, Vivoactive',
    live: true,
    tested: false,
    steps: [
      'На часах: удерживайте виджет пульса → Параметры → «Трансляция ЧСС»',
      'Или: меню → Здоровье и самочувствие → Пульс на запястье → «Трансляция ЧСС»',
      'В IronRise нажмите «Найти датчик» и выберите часы',
      'Трансляция заметно тратит батарею — выключайте после тренировки',
    ],
  ),
  (
    id: 'polar',
    brand: 'Polar',
    models: 'Ignite, Unite, Pacer, Vantage',
    live: true,
    tested: false,
    steps: [
      'На часах: «Начать тренировку» → выберите вид спорта',
      'Откройте быстрое меню → «Поделиться ЧСС с другими устройствами»',
      'На Pacer: кнопка подсветки → «Использовать часы как датчик ЧСС»',
      'В IronRise нажмите «Найти датчик» и выберите часы',
    ],
  ),
  (
    id: 'coros',
    brand: 'COROS',
    models: 'Pace, Apex, Vertix',
    live: true,
    tested: false,
    steps: [
      'На часах: удерживайте кнопку «Назад» → меню инструментов → «Трансляция пульса»',
      'В IronRise нажмите «Найти датчик» и выберите часы',
    ],
  ),
  (
    id: 'amazfit',
    brand: 'Amazfit',
    models: 'на Zepp OS 3 и новее',
    live: true,
    tested: false,
    steps: [
      'Обновите часы: нужна Zepp OS 3.0 или новее',
      'На часах найдите «Отправка пульса» (Heart Rate Push) и включите',
      'Некоторые модели транслируют пульс только во время тренировки — начните её на часах',
      'В IronRise нажмите «Найти датчик» и выберите часы',
      'Нет такого пункта — подключите Health Connect через Zepp',
    ],
  ),
  (
    id: 'xiaomi',
    brand: 'Xiaomi, Redmi',
    models: 'Smart Band 8 и новее, Watch',
    live: false,
    tested: false,
    steps: [
      'Пульс по Bluetooth другим приложениям эти браслеты не отдают',
      'Подключите Health Connect: Mi Fitness → Профиль → Подключения → Health Connect',
      'Пульс подтянется в IronRise после тренировки — она тоже подтвердится',
    ],
  ),
  (
    id: 'wearos',
    brand: 'Samsung Galaxy Watch',
    models: 'и другие часы на Wear OS',
    live: true,
    tested: true,
    steps: [
      'Лучше всего — IronRise на часах: пульс идёт сам, когда начинаете тренировку на телефоне',
      'Без него — Health Connect через Samsung Health: пульс подтянется после тренировки',
    ],
  ),
  (
    id: 'strap',
    brand: 'Нагрудный датчик',
    models: 'Polar H9/H10, Garmin HRM, COROS и другие',
    live: true,
    tested: false,
    steps: [
      'Смочите электроды водой и наденьте ремень под грудью',
      'Датчик начнёт транслировать пульс сам',
      'В IronRise нажмите «Найти датчик» и выберите его',
    ],
  ),
];

WatchGuide? watchGuideById(String id) =>
    watchGuides.where((g) => g.id == id).firstOrNull;
