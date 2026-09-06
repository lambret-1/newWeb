import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../native/native_bridge.dart';
import 'adblock_custom_service.dart';

/// 广告拦截服务：内置规则 + 用户自定义规则 → 编译注入 WKContentRuleList。
class AdBlockService {
  AdBlockService._();

  static final AdBlockService instance = AdBlockService._();

  bool _initialized = false;

  /// App 启动 / 自定义规则变更时调用：合并内置与自定义规则、注入原生。
  Future<bool> init() async {
    try {
      await AdblockCustomService.instance.ensureLoaded();

      final rules = <dynamic>[];
      final raw = await rootBundle.loadString('assets/adblock_rules.json');
      rules.addAll(jsonDecode(raw) as List);

      // 追加用户自定义规则（拦截域名 / 隐藏元素 / 高级 JSON / 豁免白名单）
      rules.addAll(AdblockCustomService.instance.buildCustomRules());

      final ok = await NativeBridge.injectContentBlocker(jsonEncode(rules));
      _initialized = ok;
      return ok;
    } catch (e) {
      debugPrint('[AdBlock] 规则注入失败: $e');
      return false;
    }
  }

  /// 规则变更后强制重新注入。
  Future<bool> reload() async {
    _initialized = false;
    return init();
  }

  /// 幂等补注入（WebView 就绪后调用）。
  Future<void> ensureInjected() async {
    if (_initialized) return;
    await init();
  }
}
