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
  static const String kTranslateMode = 'translate_mode';
  static const String kAutoTranslateDomains = 'auto_translate_domains';
  static const String kAutoTranslateEnhanced = 'auto_translate_enhanced';
  static const String kAdblockWhitelist = 'adblock_whitelist';

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

  // ---- 网页翻译 ----

  /// 翻译模式：auto（在线优先，词库兜底）/ online（仅在线）/ offline（仅本地词库）。
  static const Map<String, String> translateModes = {
    'auto': '自动',
    'online': '仅在线',
    'offline': '仅离线',
  };

  Future<String> getTranslateMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kTranslateMode) ?? 'auto';
  }

  Future<void> setTranslateMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTranslateMode, mode);
  }

  /// 自动翻译网址白名单（域名列表）。
  Future<List<String>> getAutoTranslateDomains() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(kAutoTranslateDomains) ?? [])
        .map((d) => d.trim().toLowerCase())
        .where((d) => d.isNotEmpty)
        .toList();
  }

  Future<void> setAutoTranslateDomains(List<String> domains) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kAutoTranslateDomains, domains);
  }

  /// 域名是否命中自动翻译白名单。
  /// 增强版开启时，所有域名都自动翻译。
  Future<bool> shouldAutoTranslate(String host) async {
    if (host.isEmpty) return false;
    final enhanced = await isAutoTranslateEnhanced();
    if (enhanced) return true;
    final lower = host.toLowerCase();
    final domains = await getAutoTranslateDomains();
    return domains.any((d) => lower == d || lower.endsWith('.$d'));
  }

  /// 自动翻译增强版开关（开启后所有网页自动翻译）。
  Future<bool> isAutoTranslateEnhanced() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kAutoTranslateEnhanced) ?? false;
  }

  Future<void> setAutoTranslateEnhanced(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAutoTranslateEnhanced, value);
  }

  // ---- 广告拦截豁免 ----

  Future<List<String>> getAdblockWhitelist() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(kAdblockWhitelist) ?? [])
        .map((d) => d.trim().toLowerCase())
        .where((d) => d.isNotEmpty)
        .toList();
  }

  Future<void> setAdblockWhitelist(List<String> domains) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kAdblockWhitelist, domains);
  }
}
