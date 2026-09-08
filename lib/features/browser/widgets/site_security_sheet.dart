import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/services/site_security_manager.dart';

/// 网页安全级别。
enum SecurityLevel { secure, weak, mixed, insecure, danger }

/// 底部弹出的网站安全详情面板。
class SiteSecuritySheet extends StatefulWidget {
  final String domain;
  final SecurityLevel level;
  final bool isTabLocked;
  final int adBlockCount;
  final bool dnsEnabled;
  final SiteSecurityConfig config;
  final ValueChanged<bool> onToggleLock;
  final ValueChanged<bool> onForceHttps;
  final ValueChanged<SitePermission> onCameraChanged;
  final ValueChanged<SitePermission> onMicrophoneChanged;
  final ValueChanged<SitePermission> onLocationChanged;
  final ValueChanged<SitePermission> onPhotoChanged;
  final ValueChanged<SitePermission> onPopupChanged;
  final VoidCallback onClearSiteData;

  const SiteSecuritySheet({
    super.key,
    required this.domain,
    required this.level,
    required this.isTabLocked,
    required this.adBlockCount,
    required this.dnsEnabled,
    required this.config,
    required this.onToggleLock,
    required this.onForceHttps,
    required this.onCameraChanged,
    required this.onMicrophoneChanged,
    required this.onLocationChanged,
    required this.onPhotoChanged,
    required this.onPopupChanged,
    required this.onClearSiteData,
  });

  @override
  State<SiteSecuritySheet> createState() => _SiteSecuritySheetState();
}

class _SiteSecuritySheetState extends State<SiteSecuritySheet> {
  (Color, String, IconData) get _levelInfo {
    switch (widget.level) {
      case SecurityLevel.secure:
        return (const Color(0xFF34C759), '连接安全', Icons.lock);
      case SecurityLevel.weak:
        return (const Color(0xFFFF9500), '加密但证书可信度低', Icons.lock_outline);
      case SecurityLevel.mixed:
        return (const Color(0xFFFF9500), '存在混合不安全内容', Icons.warning_amber);
      case SecurityLevel.insecure:
        return (const Color(0xFFFF9500), '未加密连接', Icons.warning_amber);
      case SecurityLevel.danger:
        return (const Color(0xFFFF3B30), '风险警告', Icons.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, statusText, icon) = _levelInfo;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖拽条
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 头部：域名 + 安全状态
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.domain,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          style: TextStyle(fontSize: 12, color: color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E5EA)),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  // 安全信息区
                  _sectionTitle('安全信息'),
                  _infoRow('加密协议', 'TLS 1.3'),
                  _infoRow('证书状态', widget.level == SecurityLevel.secure ? '有效可信' : '未知'),
                  _infoRow('DNS 过滤', widget.dnsEnabled ? '已保护' : '未开启'),
                  _infoRow('广告拦截', '本页已拦截 ${widget.adBlockCount} 条'),
                  const SizedBox(height: 8),
                  // 站点权限区
                  _sectionTitle('站点权限'),
                  _permissionRow('相机', widget.config.camera, widget.onCameraChanged),
                  _permissionRow('麦克风', widget.config.microphone, widget.onMicrophoneChanged),
                  _permissionRow('位置', widget.config.location, widget.onLocationChanged),
                  _permissionRow('相册', widget.config.photo, widget.onPhotoChanged),
                  _permissionRow('弹窗跳转', widget.config.popup, widget.onPopupChanged),
                  const SizedBox(height: 8),
                  // 快捷操作区
                  _sectionTitle('快捷操作'),
                  SwitchListTile(
                    dense: true,
                    title: const Text('锁定当前标签', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('锁定后不可关闭，重启保留',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
                    value: widget.isTabLocked,
                    activeColor: const Color(0xFF007AFF),
                    onChanged: widget.onToggleLock,
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('强制 HTTPS 升级', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('自动把 HTTP 跳转 HTTPS',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
                    value: widget.config.forceHttps,
                    activeColor: const Color(0xFF007AFF),
                    onChanged: widget.onForceHttps,
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFFF3B30)),
                    title: const Text('清除本站 Cookie 和缓存',
                        style: TextStyle(fontSize: 14, color: Color(0xFFFF3B30))),
                    onTap: () {
                      widget.onClearSiteData();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 8),
                  // 风险提示区（仅危险页面显示）
                  if (widget.level == SecurityLevel.danger) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '该网站存在安全风险，建议不要输入个人信息或密码。',
                        style: TextStyle(fontSize: 12, color: Color(0xFFFF3B30)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8E8E93),
          ),
        ),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF3A3A3C))),
            Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
          ],
        ),
      );

  Widget _permissionRow(
    String label,
    SitePermission value,
    ValueChanged<SitePermission> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF3A3A3C))),
          ),
          CupertinoSegmentedControl<SitePermission>(
            padding: EdgeInsets.zero,
            groupValue: value,
            onValueChanged: onChanged,
            children: const {
              SitePermission.ask: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('询问', style: TextStyle(fontSize: 11)),
              ),
              SitePermission.allow: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('允许', style: TextStyle(fontSize: 11)),
              ),
              SitePermission.deny: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('拒绝', style: TextStyle(fontSize: 11)),
              ),
            },
          ),
        ],
      ),
    );
  }
}
