import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../native/native_bridge.dart';
import 'settings_service.dart';

/// 广告拦截服务：加载 WKContentRuleList 规则（基础规则 + 豁免站点）并注入原生。
class AdBlockService {
  AdBlockService._();

  static final AdBlockService instance = AdBlockService._();

  bool _initialized = false;

  /// App 启动/设置变更时调用：读取规则文件、附加豁免站点规则、注入原生。
  Future<bool> init() async {
    try {
      var rules = <dynamic>[];
      final raw = await rootBundle.loadString('assets/adblock_rules.json');
      rules = (jsonDecode(raw) as List).toList();

      // 附加豁免站点规则（用户配置的白名单 → ignore-previous-rules）
      final whitelist = await SettingsService.instance.getAdblockWhitelist();
      if (whitelist.isNotEmpty) {
        rules.removeWhere(
          (r) =>
              r is Map &&
              r['action'] is Map &&
              (r['action'] as Map)['type'] == 'ignore-previous-rules',
        );
        rules.add({
          'trigger': {
            'url-filter':
                '^https?://([^/]*\\.)?(${whitelist.map((d) => RegExp.escape(d).replaceAll(r'\\.', '.')).join('|')})\\b[^\\s]*',
          },
          'action': {'type': 'ignore-previous-rules'},
        });
      }

      final ok = await NativeBridge.injectContentBlocker(jsonEncode(rules));
      _initialized = ok;
      return ok;
    } catch (e) {
      debugPrint('[AdBlock] 规则注入失败: $e');
      return false;
    }
  }

  /// 幂等补注入（WebView 就绪后调用）。
  Future<void> ensureInjected() async {
    if (_initialized) return;
    await init();
  }
}
