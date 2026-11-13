import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../game/anti_fraud.dart';
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
    }
    return const HeartRateState();
  }

  /// Тренировка на телефоне началась: часы сами включают пульс, трогать их не нужно.
  Future<void> startWatch() => _sendToWatch('start');

  Future<void> stopWatch() => _sendToWatch('stop');

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
          onError: (_) => _fail(
            'Не удалось начать поиск. Проверьте, что Bluetooth включён',
          ),
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

/// Сообщение от часов: «pulse;пульс;шаги;время_мс» или «stopped».
WatchMessage? parseWatchMessage(String raw) {
  if (raw == 'stopped') return const WatchStopped();
  final parts = raw.split(';');
  if (parts.length != 4 || parts[0] != 'pulse') return null;
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

final heartRateProvider = NotifierProvider<HeartRateNotifier, HeartRateState>(
  HeartRateNotifier.new,
);
