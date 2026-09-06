/// 全局配置：应用名、首页、搜索引擎、默认书签。
class AppConfig {
  AppConfig._();

  static const String appName = 'NewWeb';
  static const String appVersion = '0.1.0';

  /// 默认首页（与 Webplus 一致使用百度）。
  static const String homeUrl = 'https://www.baidu.com';

  /// 默认搜索引擎链接前缀。
  static const String searchUrl = 'https://www.baidu.com/s?wd=';

  /// 追加到 WebView UserAgent 的自定义标识（便于站点识别与后续统计）。
  static const String userAgentSuffix = 'NewWeb/0.1.0';

  /// 默认书签（M2 书签页使用）。
  static const List<({String title, String url})> defaultBookmarks = [
    (title: '百度', url: 'https://www.baidu.com'),
    (title: 'GitHub', url: 'https://github.com'),
    (title: '哔哩哔哩', url: 'https://www.bilibili.com'),
  ];

  /// 把地址栏输入规范化为可加载的 URI：
  /// - 空输入 → 首页
  /// - 带 http(s):// → 原样
  /// - 形如域名 → 补 https://
  /// - 其余 → 走搜索引擎（默认百度，可由设置切换）
  static Uri normalizeInput(String input, {String searchUrl = AppConfig.searchUrl}) {
    final text = input.trim();
    if (text.isEmpty) return Uri.parse(homeUrl);

    final lower = text.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return Uri.parse(text);
    }

    final domainLike = RegExp(
      r'^[a-z0-9-]+(\.[a-z0-9-]+)+(/[\w\-./?%&=#]*)?$',
    ).hasMatch(lower);
    if (domainLike) return Uri.parse('https://$text');

    return Uri.parse('$searchUrl${Uri.encodeQueryComponent(text)}');
  }
}
