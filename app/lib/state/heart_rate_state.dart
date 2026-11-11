import 'dart:async';

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

class SensorDevice {
  const SensorDevice({required this.id, required this.name, required this.rssi});

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
  });

  final HeartRateStatus status;
  final List<SensorDevice> found;
  final String? sensorName;
  final int? bpm;
  final String? message;

  bool get isConnected => status == HeartRateStatus.connected;

  HeartRateState copyWith({
    HeartRateStatus? status,
    List<SensorDevice>? found,
    String? sensorName,
    int? bpm,
    String? message,
  }) =>
      HeartRateState(
        status: status ?? this.status,
        found: found ?? this.found,
        sensorName: sensorName ?? this.sensorName,
        bpm: bpm ?? this.bpm,
        message: message,
      );
}

/// Живой пульс по Bluetooth. Хранит отсчёты последних часов для проверки тренировки.
class HeartRateNotifier extends Notifier<HeartRateState> {
  final _ble = FlutterReactiveBle();
  final _samples = <PulseSample>[];
  StreamSubscription<DiscoveredDevice>? _scan;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  StreamSubscription<List<int>>? _measurements;

  @override
  HeartRateState build() {
    ref.onDispose(_cancelAll);
    return const HeartRateState();
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
    _scan = _ble.scanForDevices(withServices: [_heartRateService], scanMode: ScanMode.lowLatency).listen(
      _onDiscovered,
      onError: (_) => _fail('Не удалось начать поиск. Проверьте, что Bluetooth включён'),
    );
    Future.delayed(const Duration(seconds: 15), stopScan);
  }

  Future<void> stopScan() async {
    await _scan?.cancel();
    _scan = null;
    if (state.status == HeartRateStatus.scanning) state = state.copyWith(status: HeartRateStatus.idle);
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
      found: [...others, SensorDevice(id: device.id, name: name, rssi: device.rssi)]
        ..sort((a, b) => b.rssi.compareTo(a.rssi)),
    );
  }

  void _connect(SensorDevice device) {
    state = state.copyWith(status: HeartRateStatus.connecting, sensorName: device.name);
    _connection?.cancel();
    _connection = _ble
        .connectToDevice(id: device.id, connectionTimeout: const Duration(seconds: 10))
        .listen(
          (update) => _onConnectionChanged(device, update.connectionState),
          onError: (_) => _fail('Не удалось подключиться к «${device.name}»'),
        );
  }

  void _onConnectionChanged(SensorDevice device, DeviceConnectionState connection) {
    switch (connection) {
      case DeviceConnectionState.connected:
        state = state.copyWith(status: HeartRateStatus.connected);
        _subscribeToPulse(device.id);
      case DeviceConnectionState.disconnected:
        _measurements?.cancel();
        state = HeartRateState(status: HeartRateStatus.idle, sensorName: device.name, message: 'Датчик отключился');
      case DeviceConnectionState.connecting || DeviceConnectionState.disconnecting:
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
    _measurements = _ble.subscribeToCharacteristic(characteristic).listen((data) {
      final bpm = parseHeartRateMeasurement(data);
      if (bpm == null || bpm == 0) return;
      _record(bpm);
      state = state.copyWith(bpm: bpm);
    });
  }

  void _record(int bpm) {
    final now = DateTime.now();
    _samples
      ..add(PulseSample(now, bpm))
      ..removeWhere((s) => now.difference(s.at) > _bufferLength);
  }

  Future<bool> _ensurePermissions() async {
    final results = await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    final granted = results.values.every((s) => s.isGranted || s.isLimited);
    if (!granted) _fail('Нужно разрешение на Bluetooth, чтобы найти датчик пульса');
    return granted;
  }

  void _fail(String message) => state = state.copyWith(status: HeartRateStatus.failed, message: message);

  void _cancelAll() {
    _scan?.cancel();
    _connection?.cancel();
    _measurements?.cancel();
  }
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

final heartRateProvider = NotifierProvider<HeartRateNotifier, HeartRateState>(HeartRateNotifier.new);
