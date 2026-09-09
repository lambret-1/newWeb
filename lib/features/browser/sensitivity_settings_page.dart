import 'package:flutter/material.dart';
import '../../core/services/settings_service.dart';

/// 手势灵敏度设置页：调节边缘返回/前进与下拉刷新的触发阈值。
class SensitivitySettingsPage extends StatefulWidget {
  const SensitivitySettingsPage({super.key});

  @override
  State<SensitivitySettingsPage> createState() => _SensitivitySettingsPageState();
}

class _SensitivitySettingsPageState extends State<SensitivitySettingsPage> {
  double _edgeSensitivity = 60;
  double _pullSensitivity = 80;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final edge = await SettingsService.instance.getEdgeSensitivity();
    final pull = await SettingsService.instance.getPullSensitivity();
    if (!mounted) return;
    setState(() {
      _edgeSensitivity = edge;
      _pullSensitivity = pull;
      _loaded = true;
    });
  }

  String _edgeLabel(double value) {
    if (value <= 45) return '灵敏';
    if (value <= 75) return '标准';
    return '迟钝';
  }

  String _pullLabel(double value) {
    if (value <= 60) return '灵敏';
    if (value <= 95) return '标准';
    return '迟钝';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        title: const Text('手势灵敏度', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF007AFF)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSection(
                  title: '边缘手势',
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('返回 / 前进灵敏度', style: TextStyle(fontSize: 15, color: Colors.black)),
                            Text(_edgeLabel(_edgeSensitivity), style: const TextStyle(fontSize: 14, color: Color(0xFF007AFF))),
                          ],
                        ),
                      ),
                      Slider(
                        value: _edgeSensitivity,
                        min: 40,
                        max: 100,
                        divisions: 6,
                        activeColor: const Color(0xFF007AFF),
                        label: '${_edgeSensitivity.toInt()}pt',
                        onChanged: (value) {
                          setState(() => _edgeSensitivity = value);
                        },
                        onChangeEnd: (value) {
                          SettingsService.instance.setEdgeSensitivity(value);
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('灵敏（40pt）', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                            Text('迟钝（100pt）', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  title: '下拉刷新',
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('刷新触发灵敏度', style: TextStyle(fontSize: 15, color: Colors.black)),
                            Text(_pullLabel(_pullSensitivity), style: const TextStyle(fontSize: 14, color: Color(0xFF007AFF))),
                          ],
                        ),
                      ),
                      Slider(
                        value: _pullSensitivity,
                        min: 50,
                        max: 120,
                        divisions: 7,
                        activeColor: const Color(0xFF007AFF),
                        label: '${_pullSensitivity.toInt()}pt',
                        onChanged: (value) {
                          setState(() => _pullSensitivity = value);
                        },
                        onChangeEnd: (value) {
                          SettingsService.instance.setPullSensitivity(value);
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('灵敏（50pt）', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                            Text('迟钝（120pt）', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '灵敏度越低，触发手势所需的滑动距离越短，操作越跟手；灵敏度越高，越不容易误触。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), height: 1.4),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ],
    );
  }
}
