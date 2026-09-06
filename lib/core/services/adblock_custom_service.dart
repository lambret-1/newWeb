import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'settings_service.dart';

/// 自定义规则条目（value + 启用开关）。
class CustomRuleItem {
  CustomRuleItem({required this.value, this.enabled = true});

  final String value;
  bool enabled;

  Map<String, dynamic> toJson() => {'v': value, 'on': enabled};

  factory CustomRuleItem.fromJson(Map<String, dynamic> json) => CustomRuleItem(
        value: json['v'] as String? ?? '',
        enabled: json['on'] as bool? ?? true,
      );
}

/// 自定义广告拦截规则：拦截域名 / 隐藏元素 / 豁免站点 / 高级 JSON。
/// 存储于 Application Support/adblock_custom.json，变更后通知 AdBlockService 重新注入。
class AdblockCustomService {
  AdblockCustomService._();

  static final AdblockCustomService instance = AdblockCustomService._();

  static const int maxPerType = 200;

  List<CustomRuleItem> blockDomains = [];
  List<CustomRuleItem> hiddenSelectors = [];
  List<CustomRuleItem> whitelist = [];
  List<CustomRuleItem> advancedRules = [];

  /// 变更通知（页面与注入逻辑监听）。
  final ValueNotifier<int> version = ValueNotifier(0);

  bool _loaded = false;

  Future<String> _filePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'adblock_custom.json');
  }

  /// 首次加载：读取文件 + 迁移设置页旧白名单。
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = File(await _filePath());
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        blockDomains = _parse(data['block_domains']);
        hiddenSelectors = _parse(data['hidden_selectors']);
        whitelist = _parse(data['whitelist']);
        advancedRules = _parse(data['advanced']);
      }
      // 迁移设置页旧豁免站点（一次）
      final legacy = await SettingsService.instance.getAdblockWhitelist();
      if (legacy.isNotEmpty && whitelist.isEmpty) {
        whitelist = legacy.map((d) => CustomRuleItem(value: d)).toList();
        await SettingsService.instance.setAdblockWhitelist(const []);
        await save();
      }
    } catch (e) {
      debugPrint('[AdBlockCustom] 加载失败: $e');
    }
  }

  List<CustomRuleItem> _parse(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CustomRuleItem.fromJson)
        .where((e) => e.value.isNotEmpty)
        .toList();
  }

  /// 保存到文件并通知变更。
  Future<void> save() async {
    try {
      final file = File(await _filePath());
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'block_domains': blockDomains.map((e) => e.toJson()).toList(),
        'hidden_selectors': hiddenSelectors.map((e) => e.toJson()).toList(),
        'whitelist': whitelist.map((e) => e.toJson()).toList(),
        'advanced': advancedRules.map((e) => e.toJson()).toList(),
      }));
      version.value++;
    } catch (e) {
      debugPrint('[AdBlockCustom] 保存失败: $e');
    }
  }

  // ---- 输入清洗与规则生成 ----

  /// 清洗用户输入的域名：去 https:// 前缀、去路径/查询/锚点、去端口、小写。
  static String normalizeDomainInput(String raw) {
    var s = raw.trim().toLowerCase();
    for (final prefix in ['https://', 'http://']) {
      if (s.startsWith(prefix)) {
        s = s.substring(prefix.length);
        break;
      }
    }
    for (final cut in ['/', '?', '#']) {
      final i = s.indexOf(cut);
      if (i >= 0) s = s.substring(0, i);
    }
    final colon = s.indexOf(':');
    if (colon >= 0) s = s.substring(0, colon);
    while (s.endsWith('.')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// 域名 → WKContentRuleList url-filter 正则（默认匹配所有子域，支持 * 通配）。
  static String domainToUrlFilter(String domain) {
    final escaped = domain.split('*').map(RegExp.escape).join('.*');
    return '^https?://(([a-z0-9-]+\\.)*)$escaped(\$|[/?#])';
  }

  /// 组装自定义规则数组（不含内置规则）。
  List<Map<String, dynamic>> buildCustomRules() {
    final rules = <Map<String, dynamic>>[];

    for (final item in blockDomains) {
      if (!item.enabled || item.value.isEmpty) continue;
      rules.add({
        'trigger': {'url-filter': domainToUrlFilter(item.value)},
        'action': {'type': 'block'},
      });
    }

    for (final item in hiddenSelectors) {
      if (!item.enabled || item.value.isEmpty) continue;
      rules.add({
        'trigger': {'url-filter': '.*'},
        'action': {'type': 'css-display-none', 'selector': item.value},
      });
    }

    for (final item in advancedRules) {
      if (!item.enabled || item.value.isEmpty) continue;
      try {
        final decoded = jsonDecode(item.value);
        if (decoded is List) {
          rules.addAll(decoded.whereType<Map<String, dynamic>>());
        } else if (decoded is Map<String, dynamic>) {
          rules.add(decoded);
        }
      } catch (_) {
        debugPrint('[AdBlockCustom] 高级规则解析失败: ${item.value}');
      }
    }

    // 豁免白名单放最后（ignore-previous-rules 豁免前面全部命中）
    final whitelistFilters = whitelist
        .where((e) => e.enabled && e.value.isNotEmpty)
        .map((e) => domainToUrlFilter(e.value));
    if (whitelistFilters.isNotEmpty) {
      rules.add({
        'trigger': {'url-filter': whitelistFilters.join('|')},
        'action': {'type': 'ignore-previous-rules'},
      });
    }

    return rules;
  }

  // ---- 操作 ----

  bool add(List<CustomRuleItem> list, String value) {
    final v = normalizeDomainInput(value);
    if (v.isEmpty) return false;
    if (list.any((e) => e.value == v)) return true; // 已存在
    if (list.length >= maxPerType) return false; // 超上限
    list.add(CustomRuleItem(value: v));
    return true;
  }

  void toggle(List<CustomRuleItem> list, int index, bool on) {
    if (index < 0 || index >= list.length) return;
    list[index].enabled = on;
  }

  void remove(List<CustomRuleItem> list, int index) {
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
  }
}
