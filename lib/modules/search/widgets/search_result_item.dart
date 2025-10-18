import 'package:flutter/material.dart';
import '../../models/music_entity.dart';
import '../../utils/search_highlighter.dart';

class SearchResultItem extends StatelessWidget {
  final MusicEntity music;
  final String searchQuery;
  final VoidCallback onTap;

  const SearchResultItem({
    super.key,
    required this.music,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lyricFragment = music.getLyricFragment(searchQuery);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Text(
                music.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Artista
              if (music.artist != null) ...[
                const SizedBox(height: 4),
                Text(
                  music.artist!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],

              // Fragmento da letra
              if (lyricFragment != null) ...[
                const SizedBox(height: 12),
                SearchHighlighter(
                  text: lyricFragment,
                  query: searchQuery,
                  textStyle: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  highlightStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    backgroundColor: Color(0xFFFEF3C7),
                  ),
                ),
              ],

              // Tags
              if (music.tags != null && music.tags!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: music.tags!.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber[900],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
