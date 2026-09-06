import 'package:shared_preferences/shared_preferences.dart';

/// 设置项（shared_preferences 持久化）。
class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const String kSearchEngine = 'search_engine';
  static const String kAdBlock = 'ad_block';
  static const String kIncognito = 'incognito';
  static const String kTencentSecretId = 'tencent_secret_id';
  static const String kTencentSecretKey = 'tencent_secret_key';

  static const Map<String, String> searchEngines = {
    'baidu': '百度',
    'bing': '必应',
    'google': 'Google',
  };

  /// 搜索引擎对应的搜索 URL 前缀。
  static String searchUrlOf(String engine) {
    switch (engine) {
      case 'bing':
        return 'https://www.bing.com/search?q=';
      case 'google':
        return 'https://www.google.com/search?q=';
      default:
        return 'https://www.baidu.com/s?wd=';
    }
  }

  Future<String> getSearchEngine() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kSearchEngine) ?? 'baidu';
  }

  Future<void> setSearchEngine(String engine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSearchEngine, engine);
  }

  Future<bool> isAdBlockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kAdBlock) ?? false;
  }

  Future<void> setAdBlockEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAdBlock, value);
  }

  Future<bool> isIncognitoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kIncognito) ?? false;
  }

  Future<void> setIncognitoEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kIncognito, value);
  }

  Future<String?> getTencentSecretId() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(kTencentSecretId);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<String?> getTencentSecretKey() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(kTencentSecretKey);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setTencentKeys(String secretId, String secretKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTencentSecretId, secretId);
    await prefs.setString(kTencentSecretKey, secretKey);
  }

  Future<void> clearTencentKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTencentSecretId);
    await prefs.remove(kTencentSecretKey);
  }
}
