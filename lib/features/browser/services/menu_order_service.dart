import 'package:shared_preferences/shared_preferences.dart';

/// 菜单排序服务
/// 负责保存/读取更多菜单的自定义顺序
class MenuOrderService {
  static const String _key = 'menu_order_v1';

  /// 默认菜单顺序（key 列表）
  static const List<String> defaultOrder = [
    'bookmarks',    // 书签
    'history',      // 历史
    'downloads',    // 下载
    'settings',     // 设置
    'add_bookmark', // 添加到书签
    'translate',    // 翻译此页
    'reader',       // 阅读模式
    'refresh',      // 刷新
    'screenshot',   // 截长图
    'export_pdf',   // 导出PDF
    'view_source',  // 查看源代码
    'offline',      // 离线页面
    'adblock',      // 广告拦截
    'cache',        // 缓存管理
    'dns',          // DNS过滤
    'sensitivity',  // 手势灵敏度
    'about',        // 关于
  ];

  /// 获取当前菜单顺序
  static Future<List<String>> getOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    if (saved == null || saved.isEmpty) return List.from(defaultOrder);
    // 合并：保存的顺序在前，新增的默认项在后
    final result = List<String>.from(saved);
    for (final key in defaultOrder) {
      if (!result.contains(key)) result.add(key);
    }
    return result;
  }

  /// 保存菜单顺序
  static Future<void> saveOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, order);
  }

  /// 恢复默认顺序
  static Future<void> resetOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
