import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/net/api_client.dart';

void main() {
  test('адрес сервера приводится к https без «/» в конце', () {
    expect(normalizeServerUrl(' fitted-leone.trycloudflare.com/ '), 'https://fitted-leone.trycloudflare.com');
    expect(normalizeServerUrl('http://10.0.2.2:3000'), 'http://10.0.2.2:3000');
    expect(normalizeServerUrl('https://api.ironrise.app//'), 'https://api.ironrise.app');
  });
}
