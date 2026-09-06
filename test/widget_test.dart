import 'package:flutter_test/flutter_test.dart';

import 'package:newweb/core/bridge/bridge_message.dart';
import 'package:newweb/core/config/app_config.dart';

void main() {
  group('BridgeMessage', () {
    test('JSON 解码', () {
      final msg = BridgeMessage.fromJson(
        '{"id":"1","action":"ping","payload":{"a":1}}',
      );
      expect(msg.id, '1');
      expect(msg.action, 'ping');
      expect(msg.payload['a'], 1);
    });

    test('非法 JSON 抛错', () {
      expect(() => BridgeMessage.fromJson('not-json'), throwsA(anything));
    });

    test('BridgeResponse 编码', () {
      final resp = BridgeResponse(id: '1', ok: true, data: 'pong');
      final encoded = resp.encode();
      expect(encoded, contains('"id":"1"'));
      expect(encoded, contains('"ok":true'));
      expect(encoded, contains('"data":"pong"'));
    });

    test('BridgeResponse 错误分支', () {
      final resp = BridgeResponse(id: '2', ok: false, error: 'bad');
      expect(resp.encode(), contains('"error":"bad"'));
      expect(resp.encode(), isNot(contains('"data"')));
    });
  });

  group('AppConfig', () {
    test('补全协议', () {
      expect(
        AppConfig.normalizeInput('baidu.com').toString(),
        'https://baidu.com',
      );
      expect(
        AppConfig.normalizeInput('www.baidu.com/s?wd=x').toString(),
        'https://www.baidu.com/s?wd=x',
      );
    });

    test('已有协议原样保留', () {
      expect(
        AppConfig.normalizeInput('https://a.cn/x').toString(),
        'https://a.cn/x',
      );
    });

    test('非网址走搜索引擎', () {
      final url = AppConfig.normalizeInput('今天天气');
      expect(url.toString(), startsWith('https://www.baidu.com/s?wd='));
    });

    test('空输入回首页', () {
      expect(AppConfig.normalizeInput('   ').toString(), AppConfig.homeUrl);
    });
  });
}
