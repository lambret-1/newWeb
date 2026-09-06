/// 历史记录数据模型。
class HistoryEntry {
  const HistoryEntry({
    this.id,
    required this.title,
    required this.url,
    required this.visitedAt,
  });

  final int? id;
  final String title;
  final String url;
  final int visitedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'url': url,
        'visited_at': visitedAt,
      };

  factory HistoryEntry.fromMap(Map<String, Object?> map) => HistoryEntry(
        id: map['id'] as int?,
        title: (map['title'] ?? '') as String,
        url: (map['url'] ?? '') as String,
        visitedAt: (map['visited_at'] ?? 0) as int,
      );
}
