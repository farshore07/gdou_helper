import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static Future<String?> get(String key) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('cache_$key');
  }

  static Future<void> set(String key, String json) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('cache_$key', json);
    await sp.setInt('cache_${key}_ts', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> remove(String key) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('cache_$key');
    await sp.remove('cache_${key}_ts');
  }

  static Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    final keys = sp.getKeys().where((k) => k.startsWith('cache_'));
    for (final k in keys) {
      await sp.remove(k);
    }
  }
}
