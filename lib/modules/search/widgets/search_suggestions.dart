import 'package:flutter/material.dart';

class SearchSuggestions extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;

  const SearchSuggestions({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: suggestions.map((suggestion) {
          final isLast = suggestion == suggestions.last;
          return InkWell(
            onTap: () => onSuggestionTap(suggestion),
            borderRadius: BorderRadius.vertical(
              top: suggestion == suggestions.first
                  ? const Radius.circular(12)
                  : Radius.zero,
              bottom: isLast ? const Radius.circular(12) : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                border: !isLast
                    ? Border(bottom: BorderSide(color: Colors.grey[200]!))
                    : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: Colors.grey[400]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
