import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdou_helper/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const buildServer = String.fromEnvironment('API_SERVER');

  test('构建地址优先，未指定时兼容已保存地址', () async {
    SharedPreferences.setMockInitialValues({
      'api_server': 'https://saved.example.invalid',
    });
    final expected = buildServer.isEmpty
        ? 'https://saved.example.invalid'
        : buildServer;
    expect(await loadApiServer(), expected);
    expect(dio.options.baseUrl, expected);
  });

  test('全新安装只从构建参数获取后端地址', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await loadApiServer(), buildServer);
    if (buildServer.isEmpty) {
      await expectLater(
        loginJwxt('test', 'test'),
        throwsA(isA<DioException>().having(
          (e) => handleError(e).message,
          '配置提示',
          contains('API_SERVER'),
        )),
      );
    }
  });
}
