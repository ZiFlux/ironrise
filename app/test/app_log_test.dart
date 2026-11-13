import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/net/app_log.dart';

void main() {
  test('токены и пароли не попадают в журнал', () {
    expect(
      AppLog.scrub('authorization: Bearer eyJhbGc.abc-123_x'),
      'authorization: Bearer ***',
    );
    expect(
      AppLog.scrub('{"refreshToken":"q1w2e3","x":1}'),
      '{"refreshToken":"***","x":1}',
    );
    expect(AppLog.scrub('accessToken=abc.def'), 'accessToken=***');
    expect(
      AppLog.scrub('{"email":"a@b.ru","password":"s3cret!"}'),
      '{"email":"a@b.ru","password":"***"}',
    );
    expect(
      AppLog.scrub('API POST /v1/workouts/strength: 400 Validation failed'),
      'API POST /v1/workouts/strength: 400 Validation failed',
    );
  });
}
