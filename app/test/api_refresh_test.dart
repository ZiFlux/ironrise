import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ironrise/net/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'параллельные запросы без access-токена делают один обмен и не теряют вход',
    () async {
      FlutterSecureStorage.setMockInitialValues({'refresh_token': 'r1'});
      var current = 'r1';
      var refreshes = 0;
      final client = MockClient((req) async {
        if (req.url.path == '/v1/auth/refresh') {
          refreshes++;
          final sent = (jsonDecode(req.body) as Map)['refreshToken'];
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (sent != current) {
            return http.Response('{"message":"Refresh token is invalid"}', 401);
          }
          current = 'r${refreshes + 1}';
          return http.Response(
            jsonEncode({'accessToken': 'a', 'refreshToken': current}),
            200,
          );
        }
        return req.headers['authorization'] == 'Bearer a'
            ? http.Response('{"ok":true}', 200)
            : http.Response('{}', 401);
      });
      final tokens = TokenStore();
      final api = ApiClient(tokens, baseUrl: 'https://x', client: client);

      final results = await Future.wait([
        api.get('/v1/duels'),
        api.get('/v1/league'),
        api.get('/v1/me'),
      ]);

      expect(results.every((r) => r['ok'] == true), isTrue);
      expect(refreshes, 1);
      expect(await tokens.readRefresh(), current);
    },
  );
}
