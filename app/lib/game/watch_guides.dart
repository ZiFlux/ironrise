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
      'Прочитай условия и подтверди галочкой',
      'Начни на часах любую тренировку — с этого момента пульс транслируется',
      'В IronRise нажми «Найти датчик» и выбери часы',
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
      'На часах: удерживай виджет пульса → Параметры → «Трансляция ЧСС»',
      'Или: меню → Здоровье и самочувствие → Пульс на запястье → «Трансляция ЧСС»',
      'В IronRise нажми «Найти датчик» и выбери часы',
      'Трансляция заметно тратит батарею — выключай после тренировки',
    ],
  ),
  (
    id: 'polar',
    brand: 'Polar',
    models: 'Ignite, Unite, Pacer, Vantage',
    live: true,
    tested: false,
    steps: [
      'На часах: «Начать тренировку» → выбери вид спорта',
      'Открой быстрое меню → «Поделиться ЧСС с другими устройствами»',
      'На Pacer: кнопка подсветки → «Использовать часы как датчик ЧСС»',
      'В IronRise нажми «Найти датчик» и выбери часы',
    ],
  ),
  (
    id: 'coros',
    brand: 'COROS',
    models: 'Pace, Apex, Vertix',
    live: true,
    tested: false,
    steps: [
      'На часах: удерживай кнопку «Назад» → меню инструментов → «Трансляция пульса»',
      'В IronRise нажми «Найти датчик» и выбери часы',
    ],
  ),
  (
    id: 'amazfit',
    brand: 'Amazfit',
    models: 'на Zepp OS 3 и новее',
    live: true,
    tested: false,
    steps: [
      'Обнови часы: нужна Zepp OS 3.0 или новее',
      'На часах найди «Отправка пульса» (Heart Rate Push) и включи',
      'Некоторые модели транслируют пульс только во время тренировки — начни её на часах',
      'В IronRise нажми «Найти датчик» и выбери часы',
      'Нет такого пункта — подключи Health Connect через Zepp',
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
      'Подключи Health Connect: Mi Fitness → Профиль → Подключения → Health Connect',
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
      'Смочи электроды водой и надень ремень под грудью',
      'Датчик начнёт транслировать пульс сам',
      'В IronRise нажми «Найти датчик» и выбери его',
    ],
  ),
];

WatchGuide? watchGuideById(String id) =>
    watchGuides.where((g) => g.id == id).firstOrNull;
