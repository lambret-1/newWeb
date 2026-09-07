import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/bookmark.dart';
import '../models/history_entry.dart';

/// SQLite 本地存储：书签 + 历史记录。
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'newweb.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _dbName),
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            url TEXT NOT NULL UNIQUE,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            url TEXT NOT NULL,
            visited_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_history_visited ON history(visited_at DESC)',
        );
      },
    );
  }

  // ---------- 书签 ----------

  Future<List<Bookmark>> getBookmarks() async {
    final db = await database;
    final rows = await db.query('bookmarks', orderBy: 'created_at DESC');
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<Bookmark?> findBookmarkByUrl(String url) async {
    final db = await database;
    final rows = await db.query(
      'bookmarks',
      where: 'url = ?',
      whereArgs: [url],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Bookmark.fromMap(rows.first);
  }

  Future<void> addBookmark(String title, String url) async {
    final db = await database;
    await db.insert(
      'bookmarks',
      Bookmark(
        title: title,
        url: url,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteBookmark(int id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateBookmark(int id, String title, String url) async {
    final db = await database;
    await db.update(
      'bookmarks',
      {'title': title, 'url': url},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 首次使用时写入默认书签（百度 / GitHub / 哔哩哔哩）。
  Future<void> initDefaultBookmarks() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM bookmarks'),
    );
    if (count != null && count > 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaults = [
      ('百度', 'https://www.baidu.com'),
      ('GitHub', 'https://github.com'),
      ('哔哩哔哩', 'https://www.bilibili.com'),
    ];
    final batch = db.batch();
    for (final (title, url) in defaults) {
      batch.insert(
        'bookmarks',
        Bookmark(title: title, url: url, createdAt: now).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // ---------- 历史 ----------

  Future<List<HistoryEntry>> getHistory({int limit = 200}) async {
    final db = await database;
    final rows = await db.query(
      'history',
      orderBy: 'visited_at DESC',
      limit: limit,
    );
    return rows.map(HistoryEntry.fromMap).toList();
  }

  Future<void> addHistory(String title, String url) async {
    if (url.isEmpty || url.startsWith('about:')) return;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 同一 URL 在 30 秒内不重复记录
    final recent = await db.query(
      'history',
      where: 'url = ? AND visited_at > ?',
      whereArgs: [url, now - 30 * 1000],
      limit: 1,
    );
    if (recent.isNotEmpty) {
      // 仅更新时间，避免列表重复
      await db.update(
        'history',
        {'visited_at': now},
        where: 'url = ?',
        whereArgs: [url],
      );
      return;
    }

    await db.insert(
      'history',
      HistoryEntry(title: title, url: url, visitedAt: now).toMap(),
    );

    // 控制历史总量：超过 1000 条删除最旧
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM history'),
    );
    if (count != null && count > 1000) {
      await db.rawDelete(
        'DELETE FROM history WHERE id NOT IN '
        '(SELECT id FROM history ORDER BY visited_at DESC LIMIT 1000)',
      );
    }
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('history');
  }

  Future<void> deleteHistoryEntry(int id) async {
    final db = await database;
    await db.delete('history', where: 'id = ?', whereArgs: [id]);
  }
}
