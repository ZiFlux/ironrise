/// Окружение сборки (docs/DEV.md).
///
/// - dev — отладочная сборка (`flutter run`): локальный сервер разработки,
///   своя база, метка DEV. Реальные бета-тестеры отсюда не видны.
/// - beta — релизная сборка для тестировщиков: сервер беты.
///
/// По умолчанию debug → dev, release → beta; можно задать явно: --dart-define=ENV=beta.
library;

enum AppEnv { dev, beta }

const _isRelease = bool.fromEnvironment('dart.vm.product');
const _envName = String.fromEnvironment(
  'ENV',
  defaultValue: _isRelease ? 'beta' : 'dev',
);

const appEnv = _envName == 'beta' ? AppEnv.beta : AppEnv.dev;

bool get isDev => appEnv == AppEnv.dev;
