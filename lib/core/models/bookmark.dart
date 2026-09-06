/// 书签数据模型。
class Bookmark {
  const Bookmark({
    this.id,
    required this.title,
    required this.url,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final String url;
  final int createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'url': url,
        'created_at': createdAt,
      };

  factory Bookmark.fromMap(Map<String, Object?> map) => Bookmark(
        id: map['id'] as int?,
        title: (map['title'] ?? '') as String,
        url: (map['url'] ?? '') as String,
        createdAt: (map['created_at'] ?? 0) as int,
      );
}
