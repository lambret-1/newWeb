/// 密码本条目：保存网站的登录账号密码。
class PasswordEntry {
  final int? id;
  final String domain; // 主域名，如 example.com
  final String username;
  final String password;
  final String? title; // 网站名称，可选
  final String? note; // 备注，可选
  final int createdAt;
  final int updatedAt;

  const PasswordEntry({
    this.id,
    required this.domain,
    required this.username,
    required this.password,
    this.title,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'domain': domain,
        'username': username,
        'password': password,
        'title': title,
        'note': note,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory PasswordEntry.fromMap(Map<String, dynamic> map) => PasswordEntry(
        id: map['id'] as int?,
        domain: map['domain'] as String,
        username: map['username'] as String,
        password: map['password'] as String,
        title: map['title'] as String?,
        note: map['note'] as String?,
        createdAt: map['created_at'] as int,
        updatedAt: map['updated_at'] as int,
      );

  PasswordEntry copyWith({
    int? id,
    String? domain,
    String? username,
    String? password,
    String? title,
    String? note,
    int? createdAt,
    int? updatedAt,
  }) =>
      PasswordEntry(
        id: id ?? this.id,
        domain: domain ?? this.domain,
        username: username ?? this.username,
        password: password ?? this.password,
        title: title ?? this.title,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// 从 URL 提取主域名（去掉 www. 和路径）。
  static String domainOf(String url) {
    try {
      final uri = Uri.parse(url);
      String host = uri.host;
      if (host.startsWith('www.')) host = host.substring(4);
      return host;
    } catch (_) {
      return url;
    }
  }
}
