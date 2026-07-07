import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _store = FlutterSecureStorage();

Future<void> secureWrite(String key, String value) =>
    _store.write(key: key, value: value);

Future<String?> secureRead(String key) => _store.read(key: key);

Future<void> secureDelete(String key) => _store.delete(key: key);

// ── 语义化读写 ──
Future<void> saveCookie(String cookie) => secureWrite('jwxt_cookie', cookie);
Future<String?> loadCookie() => secureRead('jwxt_cookie');

Future<void> savePassword(String pwd) => secureWrite('saved_password', pwd);
Future<String?> loadPassword() => secureRead('saved_password');

Future<void> saveElectricityToken(String token) =>
    secureWrite('electricity_token', token);
Future<String?> loadElectricityToken() => secureRead('electricity_token');

Future<void> clearAllSecure() => _store.deleteAll();
