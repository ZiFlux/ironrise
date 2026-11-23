import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../game/anti_fraud.dart';
import 'achievements.dart';
import 'providers.dart';

/// Стандартный Bluetooth-профиль пульса: его транслируют нагрудные датчики
/// и многие часы в режиме «трансляция пульса».
final _heartRateService = Uuid.parse('180d');
final _heartRateMeasurement = Uuid.parse('2a37');
const _savedSensorKey = 'heart_rate_sensor_v1';
const _bufferLength = Duration(hours: 4);

enum HeartRateStatus { idle, scanning, connecting, connected, failed }

/// Откуда идёт живой пульс.
enum PulseSource { bluetooth, watch }

/// Канал приёма сообщений от приложения IronRise на часах (MainActivity.kt).
const _watchChannel = EventChannel('ironrise/watch');

/// Команды приложению на часах: начать и закончить передачу пульса.
const _watchControl = MethodChannel('ironrise/watch_control');

/// Аура вспыхнула в дуэли — вибрация и вспышка на часах (п. 83). Нет часов — ничего.
Future<void> flashAuraOnWatch(String kind) async {
  try {
    await _watchControl.invokeMethod<bool>('auraFlash', {'kind': kind});
  } on PlatformException {
    // Часов нет или нет Google Play Services.
  } on MissingPluginException {
    // Тесты и не Android.
  }
}

/// Часы молчат дольше этого — считаем, что тренировка на них остановлена.
const _watchSilenceLimit = Duration(seconds: 15);

class SensorDevice {
  const SensorDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });

  final String id;
  final String name;
  final int rssi;
}

class HeartRateState {
  const HeartRateState({
    this.status = HeartRateStatus.idle,
    this.found = const [],
    this.sensorName,
    this.bpm,
    this.message,
    this.source,
  });

  final HeartRateStatus status;
  final List<SensorDevice> found;
  final String? sensorName;
  final int? bpm;
  final String? message;
  final PulseSource? source;

  bool get isConnected => status == HeartRateStatus.connected;

  HeartRateState copyWith({
    HeartRateStatus? status,
    List<SensorDevice>? found,
    String? sensorName,
    int? bpm,
    String? message,
    PulseSource? source,
  }) => HeartRateState(
    status: status ?? this.status,
    found: found ?? this.found,
    sensorName: sensorName ?? this.sensorName,
    bpm: bpm ?? this.bpm,
    message: message,
    source: source ?? this.source,
  );
}

/// Живой пульс по Bluetooth. Хранит отсчёты последних часов для проверки тренировки.
class HeartRateNotifier extends Notifier<HeartRateState> {
  // Создаётся при первом поиске датчика: без датчика Bluetooth при запуске не трогаем.
  late final _ble = FlutterReactiveBle();
  final _samples = <PulseSample>[];
  StreamSubscription<DiscoveredDevice>? _scan;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  StreamSubscription<List<int>>? _measurements;
  StreamSubscription<dynamic>? _watch;
  Timer? _watchSilence;

  @override
  HeartRateState build() {
    ref.onDispose(_cancelAll);
    _samples.addAll(_loadSavedPulse());
    if (Platform.isAndroid) {
      _watch = _watchChannel.receiveBroadcastStream().listen(
        (event) => _onWatchMessage(parseWatchMessage(event as String)),
        onError: (_) {},
      );
      // Какая версия на часах — чтобы предупредить, если отстаёт от телефона.
      Future.microtask(askWatchVersion);
    }
    return const HeartRateState();
  }

  /// Тренировка на телефоне началась: часы сами включают пульс, трогать их не нужно.
  Future<void> startWatch() => _sendToWatch('start');

  Future<void> stopWatch() => _sendToWatch('stop');

  /// Спросить у часов версию приложения (ответ — WatchVersion).
  Future<void> askWatchVersion() => _sendToWatch('hello');

  Future<void> _sendToWatch(String command) async {
    if (!Platform.isAndroid) return;
    try {
      await _watchControl.invokeMethod<bool>(command);
    } on PlatformException {
      // Часов нет или нет Google Play Services: тренировка идёт и без них.
    }
  }

  /// Пульс с приложения на часах. Bluetooth-датчик, если подключён, главнее.
  void _onWatchMessage(WatchMessage? message) {
    final bluetoothActive =
        state.isConnected && state.source == PulseSource.bluetooth;
    if (message is WatchCaps) {
      ref.read(watchCapsProvider.notifier).set(message);
      return;
    }
    if (message is WatchVersion) {
      ref.read(watchVersionProvider.notifier).set(message.version);
      // Часы ответили — подключены: награда за первое подключение.
      ref.read(achievementsProvider.notifier).claim(Achievement.watch);
      return;
    }
    if (message == null || bluetoothActive) return;
    if (message is WatchStopped) {
      _watchStopped('Тренировка на часах завершена');
      return;
    }
    final pulse = message as WatchPulse;
    _record(pulse.bpm, at: pulse.at);
    state = state.copyWith(
      status: HeartRateStatus.connected,
      source: PulseSource.watch,
      sensorName: 'Часы',
      bpm: pulse.bpm,
    );
    _watchSilence?.cancel();
    _watchSilence = Timer(
      _watchSilenceLimit,
      () => _watchStopped('Часы перестали передавать пульс'),
    );
  }

  void _watchStopped(String message) {
    _watchSilence?.cancel();
    if (state.source != PulseSource.watch) return;
    state = HeartRateState(message: message);
  }

  List<PulseSample> samplesBetween(DateTime from, DateTime to) =>
      _samples.where((s) => !s.at.isBefore(from) && !s.at.isAfter(to)).toList();

  /// Подключиться к датчику, который уже выбирали раньше.
  Future<void> reconnectSaved() async {
    if (state.isConnected || state.status == HeartRateStatus.connecting) return;
    final id = ref.read(prefsProvider).getString(_savedSensorKey);
    if (id == null || !await _ensurePermissions()) return;
    _connect(SensorDevice(id: id, name: 'Датчик пульса', rssi: 0));
  }

  Future<void> startScan() async {
    if (!await _ensurePermissions()) return;
    await _scan?.cancel();
    state = state.copyWith(status: HeartRateStatus.scanning, found: const []);
    _scan = _ble
        .scanForDevices(
          withServices: [_heartRateService],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          _onDiscovered,
          onError: (_) =>
              _fail('Не удалось начать поиск. Проверь, что Bluetooth включён'),
        );
    Future.delayed(const Duration(seconds: 15), stopScan);
  }

  Future<void> stopScan() async {
    await _scan?.cancel();
    _scan = null;
    if (state.status == HeartRateStatus.scanning)
      state = state.copyWith(status: HeartRateStatus.idle);
  }

  Future<void> connect(SensorDevice device) async {
    await stopScan();
    await ref.read(prefsProvider).setString(_savedSensorKey, device.id);
    _connect(device);
  }

  Future<void> disconnect() async {
    await ref.read(prefsProvider).remove(_savedSensorKey);
    await _measurements?.cancel();
    await _connection?.cancel();
    state = const HeartRateState();
  }

  void _onDiscovered(DiscoveredDevice device) {
    final others = state.found.where((d) => d.id != device.id);
    final name = device.name.isEmpty ? 'Без названия' : device.name;
    state = state.copyWith(
      found: [
        ...others,
        SensorDevice(id: device.id, name: name, rssi: device.rssi),
      ]..sort((a, b) => b.rssi.compareTo(a.rssi)),
    );
  }

  void _connect(SensorDevice device) {
    state = state.copyWith(
      status: HeartRateStatus.connecting,
      sensorName: device.name,
    );
    _connection?.cancel();
    _connection = _ble
        .connectToDevice(
          id: device.id,
          connectionTimeout: const Duration(seconds: 10),
        )
        .listen(
          (update) => _onConnectionChanged(device, update.connectionState),
          onError: (_) => _fail('Не удалось подключиться к «${device.name}»'),
        );
  }

  void _onConnectionChanged(
    SensorDevice device,
    DeviceConnectionState connection,
  ) {
    switch (connection) {
      case DeviceConnectionState.connected:
        state = state.copyWith(status: HeartRateStatus.connected);
        _subscribeToPulse(device.id);
      case DeviceConnectionState.disconnected:
        _measurements?.cancel();
        state = HeartRateState(
          status: HeartRateStatus.idle,
          sensorName: device.name,
          message: 'Датчик отключился',
        );
      case DeviceConnectionState.connecting ||
          DeviceConnectionState.disconnecting:
        break;
    }
  }

  void _subscribeToPulse(String deviceId) {
    _measurements?.cancel();
    final characteristic = QualifiedCharacteristic(
      serviceId: _heartRateService,
      characteristicId: _heartRateMeasurement,
      deviceId: deviceId,
    );
    _measurements = _ble.subscribeToCharacteristic(characteristic).listen((
      data,
    ) {
      final bpm = parseHeartRateMeasurement(data);
      if (bpm == null || bpm == 0) return;
      _record(bpm);
      state = state.copyWith(bpm: bpm, source: PulseSource.bluetooth);
    });
  }

  void _record(int bpm, {DateTime? at}) {
    final now = DateTime.now();
    _samples
      ..add(PulseSample(at ?? now, bpm))
      ..removeWhere((s) => now.difference(s.at) > _bufferLength);
    if (now.difference(_savedAt) >= _saveEvery) _savePulse(now);
  }

  // Пульс сохраняется на телефоне: перезапуск приложения посреди тренировки
  // не должен превращать её в тренировку «без часов».
  DateTime _savedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _saveEvery = Duration(seconds: 15);
  static const _pulseKey = 'pulse_buffer_v1';

  void _savePulse(DateTime now) {
    _savedAt = now;
    final packed = _samples
        .map((s) => '${s.at.millisecondsSinceEpoch}:${s.bpm}')
        .join(',');
    ref.read(prefsProvider).setString(_pulseKey, packed);
  }

  List<PulseSample> _loadSavedPulse() {
    final packed = ref.read(prefsProvider).getString(_pulseKey);
    if (packed == null || packed.isEmpty) return const [];
    final now = DateTime.now();
    return [
      for (final item in packed.split(','))
        if (_unpack(item) case final sample?
            when now.difference(sample.at) <= _bufferLength)
          sample,
    ];
  }

  static PulseSample? _unpack(String item) {
    final parts = item.split(':');
    final millis = int.tryParse(parts.first);
    final bpm = parts.length == 2 ? int.tryParse(parts.last) : null;
    if (millis == null || bpm == null) return null;
    return PulseSample(DateTime.fromMillisecondsSinceEpoch(millis), bpm);
  }

  Future<bool> _ensurePermissions() async {
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    final granted = results.values.every((s) => s.isGranted || s.isLimited);
    if (!granted)
      _fail('Нужно разрешение на Bluetooth, чтобы найти датчик пульса');
    return granted;
  }

  void _fail(String message) =>
      state = state.copyWith(status: HeartRateStatus.failed, message: message);

  void _cancelAll() {
    _scan?.cancel();
    _connection?.cancel();
    _measurements?.cancel();
    _watch?.cancel();
    _watchSilence?.cancel();
  }
}

sealed class WatchMessage {
  const WatchMessage();
}

class WatchPulse extends WatchMessage {
  const WatchPulse({required this.bpm, required this.steps, required this.at});

  final int bpm;
  final int steps;
  final DateTime at;
}

class WatchStopped extends WatchMessage {
  const WatchStopped();
}

/// Версия приложения на часах — ответ на «hello».
class WatchVersion extends WatchMessage {
  const WatchVersion(this.version);

  final String version;
}

/// Что умеют часы — ответ новых часов на «hello» (старые не шлют, тогда протокол 1).
class WatchCaps extends WatchMessage {
  const WatchCaps({required this.protocol, required this.auras});

  final int protocol;

  /// Ауры, которые часы умеют рисовать (id из AuraKind).
  final Set<String> auras;
}

/// Протокол часов, который понимает этот телефон. Всё, что сверх, — игнорируется,
/// так что любые часы с протоколом ≥ 1 передают пульс при любой версии телефона.
const watchProtocol = 2;

/// Сообщение от часов: «pulse;пульс;шаги;время_мс[;…]», «stopped», «version;1.1.0»
/// или «caps;proto=2;auras=fury,guard». Лишние поля от более новых часов
/// пропускаем, непонятное — отбрасываем.
WatchMessage? parseWatchMessage(String raw) {
  if (raw == 'stopped' || raw.startsWith('stopped;')) {
    return const WatchStopped();
  }
  if (raw.startsWith('version;')) {
    final v = raw.substring(8).split(';').first.trim();
    return v.isEmpty ? null : WatchVersion(v);
  }
  if (raw.startsWith('caps;')) {
    final fields = {
      for (final kv in raw.substring(5).split(';'))
        if (kv.split('=') case [final k, final v]) k.trim(): v.trim(),
    };
    return WatchCaps(
      protocol: int.tryParse(fields['proto'] ?? '') ?? 1,
      auras: {
        for (final a in (fields['auras'] ?? '').split(','))
          if (a.trim().isNotEmpty) a.trim(),
      },
    );
  }
  final parts = raw.split(';');
  if (parts.length < 4 || parts[0] != 'pulse') return null;
  final bpm = int.tryParse(parts[1]);
  final steps = int.tryParse(parts[2]);
  final millis = int.tryParse(parts[3]);
  if (bpm == null || steps == null || millis == null || bpm <= 0) return null;
  return WatchPulse(
    bpm: bpm,
    steps: steps,
    at: DateTime.fromMillisecondsSinceEpoch(millis),
  );
}

/// Разбор значения Heart Rate Measurement (0x2A37): первый бит флагов —
/// пульс записан одним байтом или двумя.
int? parseHeartRateMeasurement(List<int> data) {
  if (data.length < 2) return null;
  final isTwoBytes = data[0] & 0x01 == 1;
  if (!isTwoBytes) return data[1];
  if (data.length < 3) return null;
  return data[1] | (data[2] << 8);
}

/// Версия IronRise на часах; null — часы не ответили.
class WatchVersionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String version) => state = version;
}

final watchVersionProvider = NotifierProvider<WatchVersionNotifier, String?>(
  WatchVersionNotifier.new,
);

final heartRateProvider = NotifierProvider<HeartRateNotifier, HeartRateState>(
  HeartRateNotifier.new,
);

/// Возможности часов; null — часы старые (протокол 1) или не ответили.
class WatchCapsNotifier extends Notifier<WatchCaps?> {
  @override
  WatchCaps? build() => null;

  void set(WatchCaps caps) => state = caps;
}

final watchCapsProvider = NotifierProvider<WatchCapsNotifier, WatchCaps?>(
  WatchCapsNotifier.new,
);
