import 'package:flutter/material.dart';

class SearchHighlighter extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? textStyle;
  final TextStyle? highlightStyle;

  const SearchHighlighter({
    super.key,
    required this.text,
    required this.query,
    this.textStyle,
    this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: textStyle);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    int start = 0;
    int index = lowerText.indexOf(lowerQuery);

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: textStyle,
        ));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: highlightStyle ?? 
            const TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0xFFFEF3C7),
            ),
      ));

      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: textStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
