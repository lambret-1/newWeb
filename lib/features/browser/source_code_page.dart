import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

/// 网页源码查看器：获取当前网页 HTML 源码，深色代码风格展示。
/// 支持：域名标题、iOS 系统分享、关键词查找。
class SourceCodePage extends StatefulWidget {
  final String url;
  final String? title;

  const SourceCodePage({super.key, required this.url, this.title});

  @override
  State<SourceCodePage> createState() => _SourceCodePageState();
}

class _SourceCodePageState extends State<SourceCodePage> {
  String _source = '';
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _showSearch = false;
  List<int> _matchPositions = [];
  int _currentMatchIndex = -1;

  String get _domain {
    try {
      final uri = Uri.parse(widget.url);
      return uri.host;
    } catch (_) {
      return widget.url;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSource();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSource() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse(widget.url),
        headers: {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        setState(() {
          _source = response.body;
          _loading = false;
        });
      } else {
        setState(() {
          _error = '请求失败：HTTP ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载失败：$e';
        _loading = false;
      });
    }
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _source));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制全部源码'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _shareSource() async {
    await Share.share(_source, subject: '网页源码 - $_domain');
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _matchPositions.clear();
        _currentMatchIndex = -1;
      } else {
        _searchFocus.requestFocus();
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _matchPositions.clear();
        _currentMatchIndex = -1;
      });
      return;
    }
    final positions = <int>[];
    int start = 0;
    while (true) {
      final idx = _source.toLowerCase().indexOf(query.toLowerCase(), start);
      if (idx == -1) break;
      positions.add(idx);
      start = idx + query.length;
    }
    setState(() {
      _matchPositions = positions;
      _currentMatchIndex = positions.isNotEmpty ? 0 : -1;
    });
  }

  void _nextMatch() {
    if (_matchPositions.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchPositions.length;
    });
  }

  void _prevMatch() {
    if (_matchPositions.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matchPositions.length) % _matchPositions.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        title: Text(
          _domain,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
        ),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 8),
            onPressed: _loading ? null : _toggleSearch,
            child: Icon(
              _showSearch ? Icons.close : Icons.search,
              size: 22,
              color: const Color(0xFF4FC3F7),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.only(right: 8),
            onPressed: _loading ? null : _shareSource,
            child: const Icon(Icons.ios_share, size: 22, color: Color(0xFF4FC3F7)),
          ),
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: _loading ? null : _copyAll,
            child: const Text('复制', style: TextStyle(fontSize: 14, color: Color(0xFF4FC3F7))),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF2D2D2D),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '查找源码...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: _performSearch,
                      onSubmitted: (_) => _nextMatch(),
                    ),
                  ),
                  if (_matchPositions.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${_currentMatchIndex + 1}/${_matchPositions.length}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 20, color: Color(0xFF4FC3F7)),
                      onPressed: _prevMatch,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 20, color: Color(0xFF4FC3F7)),
                      onPressed: _nextMatch,
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(color: Colors.white54))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.white30),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                            const SizedBox(height: 16),
                            CupertinoButton(
                              color: const Color(0xFF4FC3F7),
                              onPressed: _loadSource,
                              child: const Text('重试', style: TextStyle(color: Colors.black)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSource,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            _source,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.5,
                              color: Color(0xFFD4D4D4),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
