import 'package:flutter/material.dart';

import '../../../core/models/bookmark.dart';
import '../../../core/models/history_entry.dart';

/// 联想候选项。
class SuggestionItem {
  final String title;
  final String url;
  final bool isBookmark;
  const SuggestionItem({required this.title, required this.url, required this.isBookmark});
}

/// 地址栏输入联想下拉面板：历史记录 + 书签匹配。
class AddressSuggestions extends StatelessWidget {
  const AddressSuggestions({
    super.key,
    required this.suggestions,
    required this.onSelect,
    required this.onDeleteHistory,
  });

  final List<SuggestionItem> suggestions;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDeleteHistory;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.white,
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final item = suggestions[index];
            return ListTile(
              dense: true,
              leading: Icon(
                item.isBookmark ? Icons.star : Icons.history,
                size: 16,
                color: item.isBookmark ? const Color(0xFFFF9500) : const Color(0xFF8E8E93),
              ),
              title: Text(
                item.title.isEmpty ? item.url : item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1C1C1E)),
              ),
              subtitle: Text(
                item.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
              ),
              trailing: !item.isBookmark
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFFC7C7CC)),
                      onPressed: () => onDeleteHistory(item.url),
                    )
                  : null,
              onTap: () => onSelect(item.url),
            );
          },
        ),
      ),
    );
  }
}

/// 从历史和书签中筛选联想项。
List<SuggestionItem> filterSuggestions(
  String query,
  List<HistoryEntry> history,
  List<Bookmark> bookmarks, {
  int limit = 15,
}) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) return [];
  final result = <SuggestionItem>[];
  final seen = <String>{};

  // 书签优先
  for (final b in bookmarks) {
    if (seen.contains(b.url)) continue;
    if (b.url.toLowerCase().contains(q) || b.title.toLowerCase().contains(q)) {
      result.add(SuggestionItem(title: b.title, url: b.url, isBookmark: true));
      seen.add(b.url);
      if (result.length >= limit) return result;
    }
  }
  // 历史记录
  for (final h in history) {
    if (seen.contains(h.url)) continue;
    if (h.url.toLowerCase().contains(q) || h.title.toLowerCase().contains(q)) {
      result.add(SuggestionItem(title: h.title, url: h.url, isBookmark: false));
      seen.add(h.url);
      if (result.length >= limit) return result;
    }
  }
  return result;
}
