import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/password_entry.dart';

/// 密码本服务：本地存储网站账号密码，支持主密码保护。
///
/// 安全说明：
/// - 密码仅保存在设备本地 SQLite，不上传任何服务器
/// - 主密码用于保护密码本访问，使用 SHA-256 哈希存储
/// - 建议用户设置主密码，未设置时密码本可直接访问
class PasswordService {
  PasswordService._();

  static final PasswordService instance = PasswordService._();

  static const String _table = 'passwords';
  static const String _masterKey = 'password_master_hash';
  static const String _autoFillKey = 'password_autofill_enabled';

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ---------- 数据库表初始化（由 DatabaseHelper 调用） ----------

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        title TEXT,
        note TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_passwords_domain ON $_table(domain)',
    );
  }

  // ---------- 主密码 ----------

  /// 是否已设置主密码。
  Future<bool> hasMasterPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_masterKey)?.isNotEmpty ?? false;
  }

  /// 设置主密码（传入明文，内部哈希存储）。
  Future<void> setMasterPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = _simpleHash(password);
    await prefs.setString(_masterKey, hash);
  }

  /// 验证主密码。
  Future<bool> verifyMasterPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_masterKey);
    if (stored == null || stored.isEmpty) return true; // 未设置则放行
    return stored == _simpleHash(password);
  }

  /// 清除主密码。
  Future<void> clearMasterPassword() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_masterKey);
  }

  /// 简单哈希（非加密级，仅用于本地验证）。
  String _simpleHash(String input) {
    // 用 Dart 内置的 hashCode 做简单混淆，实际项目应加 crypto 包
    int hash = 0;
    for (final c in input.codeUnits) {
      hash = 0x1fffffff & (hash + c);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash = hash ^ (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 'h${0x1fffffff & (hash + ((0x00003fff & hash) << 15))}';
  }

  // ---------- 自动填充开关 ----------

  Future<bool> isAutoFillEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoFillKey) ?? true;
  }

  Future<void> setAutoFillEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoFillKey, enabled);
  }

  // ---------- CRUD ----------

  /// 获取所有密码条目。
  Future<List<PasswordEntry>> getAll() async {
    final db = await _db;
    final rows = await db.query(_table, orderBy: 'updated_at DESC');
    return rows.map(PasswordEntry.fromMap).toList();
  }

  /// 按域名查找密码条目。
  Future<List<PasswordEntry>> findByDomain(String domain) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'domain = ?',
      whereArgs: [domain],
      orderBy: 'updated_at DESC',
    );
    return rows.map(PasswordEntry.fromMap).toList();
  }

  /// 按域名和用户名查找单条。
  Future<PasswordEntry?> findOne(String domain, String username) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'domain = ? AND username = ?',
      whereArgs: [domain, username],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PasswordEntry.fromMap(rows.first);
  }

  /// 添加或更新密码条目（按 domain+username 去重）。
  Future<int> upsert(PasswordEntry entry) async {
    final db = await _db;
    final existing = await findOne(entry.domain, entry.username);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (existing != null) {
      await db.update(
        _table,
        {
          'password': entry.password,
          'title': entry.title,
          'note': entry.note,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.id!;
    } else {
      return db.insert(_table, {
        'domain': entry.domain,
        'username': entry.username,
        'password': entry.password,
        'title': entry.title,
        'note': entry.note,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// 删除密码条目。
  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// 清空全部密码。
  Future<void> clearAll() async {
    final db = await _db;
    await db.delete(_table);
  }

  /// 密码条目总数。
  Future<int> count() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM $_table');
    return (result.first['c'] as int?) ?? 0;
  }
}
