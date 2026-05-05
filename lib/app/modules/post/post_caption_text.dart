import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class PostCaptionText extends StatelessWidget {
  final String caption;
  final ValueChanged<String>? onMentionTap;
  final ValueChanged<String>? onHashtagTap;
  final TextStyle? textStyle;
  final Color mentionColor;
  final Color hashtagColor;

  const PostCaptionText({
    super.key,
    required this.caption,
    this.onMentionTap,
    this.onHashtagTap,
    this.textStyle,
    this.mentionColor = const Color(0xFF1DA1F2),
    this.hashtagColor = const Color(0xFF17BF63),
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: textStyle ??
            TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 14,
              height: 1.4,
            ),
        children: _parseCaption(caption),
      ),
    );
  }

  List<TextSpan> _parseCaption(String text) {
    if (text.isEmpty) return [];

    final spans = <TextSpan>[];
    final mentionRegex = RegExp(r'(@\w+)');
    final hashtagRegex = RegExp(r'(#\w+)');

    final combinedRegex = RegExp(r'(@\w+|#\w+)');
    final matches = combinedRegex.allMatches(text);

    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(text: text.substring(lastEnd, match.start)),
        );
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('@')) {
        spans.add(
          TextSpan(
            text: matchedText,
            style: TextStyle(
              color: mentionColor,
              fontWeight: FontWeight.w500,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => onMentionTap?.call(matchedText),
          ),
        );
      } else if (matchedText.startsWith('#')) {
        spans.add(
          TextSpan(
            text: matchedText,
            style: TextStyle(
              color: hashtagColor,
              fontWeight: FontWeight.w500,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => onHashtagTap?.call(matchedText.substring(1)),
          ),
        );
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(text: text.substring(lastEnd)),
      );
    }

    return spans;
  }
}
