import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 站点权限状态。
enum SitePermission { ask, allow, deny }

/// 单个站点的安全配置。
class SiteSecurityConfig {
  final String domain;
  bool forceHttps;
  SitePermission camera;
  SitePermission microphone;
  SitePermission location;
  SitePermission photo;
  SitePermission popup;

  SiteSecurityConfig({
    required this.domain,
    this.forceHttps = false,
    this.camera = SitePermission.ask,
    this.microphone = SitePermission.ask,
    this.location = SitePermission.ask,
    this.photo = SitePermission.ask,
    this.popup = SitePermission.ask,
  });

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'forceHttps': forceHttps,
        'camera': camera.index,
        'microphone': microphone.index,
        'location': location.index,
        'photo': photo.index,
        'popup': popup.index,
      };

  factory SiteSecurityConfig.fromJson(Map<String, dynamic> json) =>
      SiteSecurityConfig(
        domain: json['domain'] as String,
        forceHttps: json['forceHttps'] as bool? ?? false,
        camera: SitePermission.values[json['camera'] as int? ?? 0],
        microphone: SitePermission.values[json['microphone'] as int? ?? 0],
        location: SitePermission.values[json['location'] as int? ?? 0],
        photo: SitePermission.values[json['photo'] as int? ?? 0],
        popup: SitePermission.values[json['popup'] as int? ?? 0],
      );
}

/// 站点安全配置管理器：按域名独立存储，持久化到 SharedPreferences。
class SiteSecurityManager {
  SiteSecurityManager._();
  static final SiteSecurityManager instance = SiteSecurityManager._();

  static const String _key = 'site_security_configs';
  final Map<String, SiteSecurityConfig> _cache = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        data.forEach((domain, json) {
          _cache[domain] =
              SiteSecurityConfig.fromJson(json as Map<String, dynamic>);
        });
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<SiteSecurityConfig> getConfig(String domain) async {
    await _ensureLoaded();
    return _cache[domain] ?? SiteSecurityConfig(domain: domain);
  }

  Future<void> saveConfig(SiteSecurityConfig config) async {
    await _ensureLoaded();
    _cache[config.domain] = config;
    await _flush();
  }

  Future<void> _flush() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{};
      _cache.forEach((domain, config) {
        data[domain] = config.toJson();
      });
      await prefs.setString(_key, jsonEncode(data));
    } catch (_) {}
  }

  /// 从 URL 提取主域名（用于配置 key）。
  static String domainOf(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      if (host.isEmpty) return url;
      return host.startsWith('www.') ? host.substring(4) : host;
    } catch (_) {
      return url;
    }
  }

  /// 清除指定域名的全部配置。
  Future<void> clearDomain(String domain) async {
    await _ensureLoaded();
    _cache.remove(domain);
    await _flush();
  }
}
