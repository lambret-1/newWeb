import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/menu_order_service.dart';
import '../../../core/services/debug_logger.dart';

/// 菜单项定义
class MenuItem {
  final String key;
  final IconData icon;
  final String label;
  final String section;
  final VoidCallback onTap;
  final bool isGrid; // 是否为顶部网格项

  const MenuItem({
    required this.key,
    required this.icon,
    required this.label,
    required this.section,
    required this.onTap,
    this.isGrid = false,
  });
}

/// 更多菜单底部弹出组件
/// 支持重力感应排序：左倾上移，右倾下移
class MoreMenuSheet extends StatefulWidget {
  final List<MenuItem> items;

  const MoreMenuSheet({super.key, required this.items});

  @override
  State<MoreMenuSheet> createState() => _MoreMenuSheetState();
}

class _MoreMenuSheetState extends State<MoreMenuSheet> {
  List<String> _order = [];
  bool _isSorting = false;
  int _selectedIndex = 0;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime _lastMove = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    final order = await MenuOrderService.getOrder();
    setState(() => _order = order);
  }

  /// 按顺序获取菜单项
  List<MenuItem> get _sortedItems {
    if (_order.isEmpty) return widget.items;
    final map = {for (var item in widget.items) item.key: item};
    final result = <MenuItem>[];
    for (final key in _order) {
      if (map.containsKey(key)) result.add(map[key]!);
    }
    // 追加未在顺序中的新项
    for (final item in widget.items) {
      if (!_order.contains(item.key)) result.add(item);
    }
    return result;
  }

  /// 进入排序模式
  void _enterSortMode() {
    setState(() {
      _isSorting = true;
      _selectedIndex = 0;
    });
    _startListening();
    DebugLogger.instance.log('进入排序模式，启动加速度传感器监听');
  }

  /// 退出排序模式并保存
  Future<void> _exitSortMode() async {
    _accelSub?.cancel();
    _accelSub = null;
    final keys = _sortedItems.map((e) => e.key).toList();
    await MenuOrderService.saveOrder(keys);
    if (mounted) {
      setState(() => _isSorting = false);
    }
    DebugLogger.instance.log('退出排序模式，保存顺序: $keys');
  }

  /// 恢复默认顺序
  Future<void> _resetOrder() async {
    await MenuOrderService.resetOrder();
    await _loadOrder();
    DebugLogger.instance.log('恢复默认顺序');
  }

  /// 监听加速度传感器
  void _startListening() {
    _accelSub = accelerometerEventStream().listen(
      (event) {
        final now = DateTime.now();
        if (now.difference(_lastMove).inMilliseconds < 250) return; // 防抖

        // x轴：设备左倾时x为负，右倾时x为正
        // 阈值：超过 1.5 触发移动（约倾斜9度）
        if (event.x < -1.5) {
          _moveSelected(-1);
          _lastMove = now;
          DebugLogger.instance.log('左倾 x=${event.x.toStringAsFixed(2)}，上移');
        } else if (event.x > 1.5) {
          _moveSelected(1);
          _lastMove = now;
          DebugLogger.instance.log('右倾 x=${event.x.toStringAsFixed(2)}，下移');
        }
      },
      onError: (e) {
        DebugLogger.instance.log('加速度传感器错误: $e');
      },
      onDone: () {
        DebugLogger.instance.log('加速度传感器监听结束');
      },
    );
  }

  /// 移动选中项
  void _moveSelected(int direction) {
    final items = _sortedItems;
    final newIndex = _selectedIndex + direction;
    if (newIndex < 0 || newIndex >= items.length) return;

    setState(() {
      // 直接交换 _order 中的位置
      final keys = List<String>.from(_order);
      // 确保 _order 包含所有项
      for (final item in items) {
        if (!keys.contains(item.key)) keys.add(item.key);
      }
      final idx1 = keys.indexOf(items[_selectedIndex].key);
      final idx2 = keys.indexOf(items[newIndex].key);
      if (idx1 >= 0 && idx2 >= 0) {
        final temp = keys[idx1];
        keys[idx1] = keys[idx2];
        keys[idx2] = temp;
      }
      _order = keys;
      _selectedIndex = newIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _sortedItems;
    final gridItems = items.where((e) => e.isGrid).toList();
    final listItems = items.where((e) => !e.isGrid).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // 顶部拖拽横条
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 标题栏 + 排序按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '更多功能',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  if (_isSorting)
                    Row(
                      children: [
                        TextButton(
                          onPressed: _resetOrder,
                          child: const Text('恢复默认',
                              style: TextStyle(fontSize: 14, color: Color(0xFF007AFF))),
                        ),
                        TextButton(
                          onPressed: _exitSortMode,
                          child: const Text('完成',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
                        ),
                      ],
                    )
                  else
                    TextButton(
                      onPressed: _enterSortMode,
                      child: const Text('排序',
                          style: TextStyle(fontSize: 14, color: Color(0xFF007AFF))),
                    ),
                ],
              ),
            ),
            if (_isSorting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  '左倾手机上移，右倾手机下移，点击完成保存',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // 顶部网格
                  if (gridItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: gridItems.map((item) {
                          final index = items.indexOf(item);
                          return _gridItem(
                            icon: item.icon,
                            label: item.label,
                            onTap: item.onTap,
                            selected: _isSorting && index == _selectedIndex,
                            onSelect: _isSorting ? () => setState(() => _selectedIndex = index) : null,
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  // 列表项（按 section 分组）
                  ..._buildListItems(listItems, items),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建列表项（按 section 分组）
  List<Widget> _buildListItems(List<MenuItem> listItems, List<MenuItem> allItems) {
    final widgets = <Widget>[];
    String? lastSection;
    for (final item in listItems) {
      if (item.section != lastSection) {
        widgets.add(_sectionTitle(item.section));
        lastSection = item.section;
      }
      final index = allItems.indexOf(item);
      widgets.add(_sheetItem(
        icon: item.icon,
        label: item.label,
        onTap: item.onTap,
        selected: _isSorting && index == _selectedIndex,
        onSelect: _isSorting ? () => setState(() => _selectedIndex = index) : null,
      ));
    }
    return widgets;
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _gridItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    VoidCallback? onSelect,
  }) {
    return GestureDetector(
      onTap: onSelect ?? onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF007AFF) : const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(14),
              border: selected ? Border.all(color: const Color(0xFF007AFF), width: 2) : null,
            ),
            child: Icon(icon, size: 24, color: selected ? Colors.white : const Color(0xFF007AFF)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? const Color(0xFF007AFF) : const Color(0xFF374151),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    VoidCallback? onSelect,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22, color: selected ? const Color(0xFF007AFF) : const Color(0xFF374151)),
      title: Text(label,
          style: TextStyle(
              fontSize: 15,
              color: selected ? const Color(0xFF007AFF) : Colors.black,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      trailing: selected
          ? const Icon(Icons.unfold_more, size: 18, color: Color(0xFF007AFF))
          : const Icon(Icons.chevron_right, size: 18, color: Color(0xFFC7C7CC)),
      tileColor: selected ? const Color(0xFFE8F0FE) : null,
      onTap: onSelect ?? onTap,
    );
  }
}
