import 'package:flutter_test/flutter_test.dart';
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
}
