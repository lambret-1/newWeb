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
