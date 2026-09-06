import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 离线页面条目。
class OfflinePage {
  const OfflinePage({
    required this.fileName,
    required this.path,
    required this.title,
    required this.size,
    required this.modifiedAt,
  });

  final String fileName;
  final String path;
  final String title;
  final int size;
  final int modifiedAt;

  String get sizeText {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// 离线完整保存：单文件 HTML 归档，存储于应用文档目录。
class OfflineService {
  OfflineService._();

  static final OfflineService instance = OfflineService._();

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'OfflinePages'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 保存离线页面，返回条目；标题取页面 title。
  Future<OfflinePage> save(String title, String url, String html) async {
    final dir = await _dir();
    final safeTitle = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim()
        .isEmpty
        ? '离线页面'
        : title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final name = '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.html';
    final file = File(p.join(dir.path, name));
    await file.writeAsString(html, flush: true);
    final stat = await file.stat();
    return OfflinePage(
      fileName: name,
      path: file.path,
      title: safeTitle,
      size: stat.size,
      modifiedAt: stat.modified.millisecondsSinceEpoch,
    );
  }

  Future<List<OfflinePage>> list() async {
    final dir = await _dir();
    final files = dir.listSync().whereType<File>().where(
          (f) => f.path.toLowerCase().endsWith('.html'),
        );
    final pages = <OfflinePage>[];
    for (final file in files) {
      final stat = await file.stat();
      final name = p.basenameWithoutExtension(file.path);
      pages.add(
        OfflinePage(
          fileName: p.basename(file.path),
          path: file.path,
          title: name,
          size: stat.size,
          modifiedAt: stat.modified.millisecondsSinceEpoch,
        ),
      );
    }
    pages.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return pages;
  }

  Future<void> delete(OfflinePage page) async {
    final file = File(page.path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 清空全部离线页面。
  Future<void> clearAll() async {
    final dir = await _dir();
    if (await dir.exists()) {
      for (final f in dir.listSync()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }
}
