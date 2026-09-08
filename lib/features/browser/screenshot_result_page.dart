import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../native/native_bridge.dart';

/// 长截图结果页：展示生成的网页长图，提供保存相册和分享。
class ScreenshotResultPage extends StatefulWidget {
  final String base64Image;
  final String pageUrl;
  final String pageTitle;

  const ScreenshotResultPage({
    super.key,
    required this.base64Image,
    required this.pageUrl,
    required this.pageTitle,
  });

  @override
  State<ScreenshotResultPage> createState() => _ScreenshotResultPageState();
}

class _ScreenshotResultPageState extends State<ScreenshotResultPage> {
  bool _saving = false;

  Future<void> _saveToGallery() async {
    setState(() => _saving = true);
    try {
      final result = await NativeBridge.saveImageToGallery(widget.base64Image);
      final success = result?['success'] == true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '已保存到相册' : '保存失败，请检查相册权限'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e'), duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    final bytes = base64Decode(widget.base64Image);
    final dir = await getTemporaryDirectory();
    final safeTitle = widget.pageTitle.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5]'), '_');
    final file = File(p.join(dir.path, '${safeTitle}_长截图.jpg'));
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: widget.pageTitle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2E),
        elevation: 0,
        title: const Text('网页长截图', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(Icons.close, size: 24, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Center(
                child: Image.memory(
                  base64Decode(widget.base64Image),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF2C2C2E),
              border: Border(top: BorderSide(color: Color(0xFF3A3A3C), width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _saving ? null : _saveToGallery,
                      child: _saving
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.download, size: 18),
                                SizedBox(width: 6),
                                Text('保存到相册', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      color: const Color(0xFF3A3A3C),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _share,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.ios_share, size: 18),
                          SizedBox(width: 6),
                          Text('分享', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
