import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'settings_service.dart';
import 'tencent_translate_client.dart';

/// 翻译服务：四级降级（在线优先，词库兜底）。
/// 1. 腾讯云机器翻译（需在设置中配置 SecretId/SecretKey）
/// 2. Google 免费接口
/// 3. MyMemory 免费接口
/// 4. 本地基础词库（单词级）
class TranslateService {
  TranslateService._();

  static final TranslateService instance = TranslateService._();

  Map<String, String>? _dict;

  Future<Map<String, String>> _loadDict() async {
    if (_dict != null) return _dict!;
    try {
      final raw = await rootBundle.loadString('assets/en_zh_dict_basic.json');
      final map = (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k.toLowerCase(), v as String));
      _dict = map;
    } catch (_) {
      _dict = {};
    }
    return _dict!;
  }

  /// 翻译文本，按模式走降级链；全部失败返回 null。
  /// mode：auto（在线优先，词库兜底）/ online（仅在线）/ offline（仅本地词库）。
  Future<String?> translate(String text, {String mode = 'auto'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 500) return '文本过长，请分段翻译（不超过 500 字符）';

    final offlineOnly = mode == 'offline';
    final onlineOnly = mode == 'online';

    if (!offlineOnly) {
      // 1. 腾讯云（已配置时优先）
      final secretId = await SettingsService.instance.getTencentSecretId();
      final secretKey = await SettingsService.instance.getTencentSecretKey();
      if (secretId != null && secretKey != null) {
        final client = TencentTranslateClient(
          secretId: secretId,
          secretKey: secretKey,
        );
        final result = await client.translate(trimmed);
        if (result != null) return result;
      }

      // 2. Google 免费接口
      final google = await _google(trimmed);
      if (google != null) return google;

      // 3. MyMemory
      final mymemory = await _mymemory(trimmed);
      if (mymemory != null) return mymemory;
    }

    if (onlineOnly) return null;

    // 4. 本地词库兜底
    return _localDict(trimmed);
  }

  Future<String?> _google(String text) async {
    try {
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
        '?client=gtx&sl=auto&tl=zh-CN&dt=t&q=${Uri.encodeQueryComponent(text)}',
      );
      final res = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      final segments = data[0] as List<dynamic>;
      final sb = StringBuffer();
      for (final seg in segments) {
        final part = (seg as List<dynamic>)[0] as String?;
        if (part != null) sb.write(part);
      }
      final result = sb.toString().trim();
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _mymemory(String text) async {
    try {
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get'
        '?q=${Uri.encodeQueryComponent(text)}&langpair=auto|zh-CN',
      );
      final res = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final responseData = data['responseData'] as Map<String, dynamic>?;
      final translated = responseData?['translatedText'] as String?;
      if (translated == null || translated.isEmpty) return null;
      // MyMemory 偶尔返回 "MYMEMORY WARNING" 提示
      if (translated.contains('MYMEMORY WARNING')) return null;
      return translated.trim();
    } catch (_) {
      return null;
    }
  }

  /// 本地词库兜底：单词级查词拼接，未知词保留原文。
  Future<String?> _localDict(String text) async {
    final dict = await _loadDict();
    if (dict.isEmpty) return null;

    // 仅处理英文文本
    final hasLetter = text.contains(RegExp(r'[a-zA-Z]'));
    if (!hasLetter) return null;

    final words = text
        .split(RegExp(r'''[\s,.;:!?()'\-]+'''))
        .where((w) => w.isNotEmpty);
    final sb = StringBuffer();
    var matched = 0;
    for (final word in words) {
      final translation = dict[word.toLowerCase()];
      if (translation != null) {
        sb.write(translation);
        matched++;
      } else {
        sb.write(word);
      }
      sb.write(' ');
    }
    if (matched == 0) return null;
    return sb.toString().trim();
  }
}
