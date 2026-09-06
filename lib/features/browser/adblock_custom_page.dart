import 'package:flutter/material.dart';

import '../../core/services/adblock_custom_service.dart';
import '../../core/services/adblock_service.dart';

/// 自定义广告拦截规则：拦截地址 / 隐藏元素 / 豁免站点 / 高级规则（JSON）。
/// 任何变更即时保存并重新注入原生拦截器。
class AdblockCustomPage extends StatefulWidget {
  const AdblockCustomPage({super.key});

  @override
  State<AdblockCustomPage> createState() => _AdblockCustomPageState();
}

class _AdblockCustomPageState extends State<AdblockCustomPage> {
  final AdblockCustomService _svc = AdblockCustomService.instance;
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _svc.ensureLoaded();
    _svc.version.addListener(_onChanged);
  }

  @override
  void dispose() {
    _svc.version.removeListener(_onChanged);
    _input.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _mutate(Future<void> Function() action) async {
    await action();
    await _svc.save();
    _showMessage('规则已更新，正在重新注入…');
    await AdBlockService.instance.reload();
    _showMessage('广告拦截规则已生效');
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _addTo(List<CustomRuleItem> list, {bool isSelector = false}) async {
    final value = _input.text;
    if (value.trim().isEmpty) return;
    var ok = false;
    if (isSelector) {
      final v = value.trim();
      if (v.isNotEmpty && list.length < AdblockCustomService.maxPerType) {
        if (!list.any((e) => e.value == v)) list.add(CustomRuleItem(value: v));
        ok = true;
      }
    } else {
      ok = _svc.add(list, value);
    }
    if (!ok) {
      _showMessage('添加失败：规则已达上限或输入无效');
      return;
    }
    _input.clear();
    await _mutate(() async {});
  }

  Future<void> _importAdvanced() async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入高级规则'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: '粘贴 WKContentRuleList JSON 规则（数组或单条对象）',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    if (_svc.advancedRules.length >= AdblockCustomService.maxPerType) {
      _showMessage('高级规则已达上限');
      return;
    }
    _svc.advancedRules.add(CustomRuleItem(value: text));
    await _mutate(() async {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F6F8),
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            '自定义规则',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF3B82F6),
            unselectedLabelColor: Color(0xFF9CA3AF),
            indicatorColor: Color(0xFF3B82F6),
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: '拦截地址'),
              Tab(text: '隐藏元素'),
              Tab(text: '豁免站点'),
              Tab(text: '高级规则'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ruleList(_svc.blockDomains, hint: '输入要拦截的域名，自动匹配子域'),
            _ruleList(_svc.hiddenSelectors,
                hint: '输入 CSS 选择器，如 #ad-banner', isSelector: true),
            _ruleList(_svc.whitelist, hint: '输入豁免站点域名（跳过拦截）'),
            _advancedList(),
          ],
        ),
      ),
    );
  }

  Widget _ruleList(List<CustomRuleItem> list,
      {required String hint, bool isSelector = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(
                          fontSize: 12, color: Color(0xFFB0B7C3)),
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _addTo(list, isSelector: isSelector),
                  ),
                ),
                TextButton(
                  onPressed: () => _addTo(list, isSelector: isSelector),
                  child: const Text('添加',
                      style: TextStyle(fontSize: 14, color: Color(0xFF3B82F6))),
                ),
              ],
            ),
          ),
        ),
        if (!isSelector)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '支持粘贴完整网址，自动去掉 https:// 前缀与路径尾缀',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ),
          ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text(
                    '暂无规则',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          item.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: item.enabled,
                              onChanged: (on) => _mutate(() async {
                                _svc.toggle(list, index, on);
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: Color(0xFFB0B7C3)),
                              onPressed: () => _mutate(() async {
                                _svc.remove(list, index);
                              }),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _advancedList() {
    final list = _svc.advancedRules;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '高级规则为完整 WKContentRuleList JSON（trigger + action），'
                    '用于精确控制拦截行为；与内置 / 简化规则按顺序合并。',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _importAdvanced,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('导入 JSON 规则'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
                side: const BorderSide(color: Color(0xFF3B82F6)),
              ),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text(
                    '暂无高级规则',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          item.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: item.enabled,
                              onChanged: (on) => _mutate(() async {
                                _svc.toggle(list, index, on);
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: Color(0xFFB0B7C3)),
                              onPressed: () => _mutate(() async {
                                _svc.remove(list, index);
                              }),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
