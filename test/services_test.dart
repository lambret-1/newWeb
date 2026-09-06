import 'package:flutter_test/flutter_test.dart';
import 'package:newweb/core/services/adblock_custom_service.dart';
import 'package:newweb/core/services/settings_service.dart';
import 'package:newweb/core/services/translate_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TranslateService 本地词库兜底', () {
    test('常见单词命中词库', () async {
      final result = await TranslateService.instance.translate('hello world');
      expect(result, contains('你好'));
      expect(result, contains('世界'));
    });

    test('未知词保留原文', () async {
      final result =
          await TranslateService.instance.translate('hello zzzunknown');
      expect(result, contains('你好'));
      expect(result, contains('zzzunknown'));
    });

    test('非英文文本不走词库', () async {
      final result = await TranslateService.instance.translate('你好世界');
      expect(result, isNull);
    });

    test('仅在线模式：测试环境无网络 → null', () async {
      final result = await TranslateService.instance
          .translate('hello world', mode: 'online');
      expect(result, isNull);
    });

    test('仅离线模式：只走词库', () async {
      final result = await TranslateService.instance
          .translate('hello world', mode: 'offline');
      expect(result, contains('你好'));
      expect(result, contains('世界'));
    });
  });

  group('SettingsService 翻译与拦截配置', () {
    test('默认翻译模式为自动', () async {
      expect(await SettingsService.instance.getTranslateMode(), 'auto');
    });

    test('翻译模式持久化', () async {
      await SettingsService.instance.setTranslateMode('offline');
      expect(await SettingsService.instance.getTranslateMode(), 'offline');
    });

    test('自动翻译白名单匹配子域名', () async {
      await SettingsService.instance
          .setAutoTranslateDomains(['en.wikipedia.org']);
      expect(
        await SettingsService.instance.shouldAutoTranslate('en.wikipedia.org'),
        true,
      );
      expect(
        await SettingsService.instance.shouldAutoTranslate('www.google.com'),
        false,
      );
    });

    test('豁免站点持久化', () async {
      await SettingsService.instance.setAdblockWhitelist(['zhihu.com']);
      final list = await SettingsService.instance.getAdblockWhitelist();
      expect(list, contains('zhihu.com'));
    });
  });

  group('SettingsService', () {
    test('默认搜索引擎为百度', () async {
      expect(await SettingsService.instance.getSearchEngine(), 'baidu');
    });

    test('搜索引擎 URL 映射', () {
      expect(SettingsService.searchUrlOf('baidu'), contains('baidu.com'));
      expect(SettingsService.searchUrlOf('bing'), contains('bing.com'));
      expect(SettingsService.searchUrlOf('google'), contains('google.com'));
    });

    test('开关持久化', () async {
      await SettingsService.instance.setAdBlockEnabled(true);
      expect(await SettingsService.instance.isAdBlockEnabled(), true);
      await SettingsService.instance.setAdBlockEnabled(false);
      expect(await SettingsService.instance.isAdBlockEnabled(), false);
    });
  });
  group('AdblockCustomService 域名清洗', () {
    test('完整网址去协议/路径/端口', () {
      expect(
        AdblockCustomService.normalizeDomainInput(
            'https://www.example.com/path/page.html?x=1'),
        'www.example.com',
      );
      expect(
        AdblockCustomService.normalizeDomainInput('http://example.com:8080/a'),
        'example.com',
      );
    });

    test('域名转 url-filter 正则匹配子域', () {
      final re =
          RegExp(AdblockCustomService.domainToUrlFilter('example.com'));
      expect(re.hasMatch('https://example.com/'), true);
      expect(re.hasMatch('https://www.example.com/ads/x.js'), true);
      expect(re.hasMatch('https://notexample.com/'), false);
    });

    test('通配符规则', () {
      final re =
          RegExp(AdblockCustomService.domainToUrlFilter('*.ads.com'));
      expect(re.hasMatch('https://a.ads.com/b'), true);
    });
  });
}