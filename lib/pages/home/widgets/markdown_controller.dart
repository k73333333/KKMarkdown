import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../utils/markdown_highlighter.dart';

/**
 * 自定义 TextEditingController，用于在编辑框中将长的 base64 图片数据折叠显示
 */
class MarkdownTextEditingController extends TextEditingController {
  final void Function(String imageId, String altText)? onImageTap;
  final void Function(String imageId, Offset position)? onImageSecondaryTap;

  List<TapGestureRecognizer> _recognizers = [];

  MarkdownTextEditingController({
    String? text,
    this.onImageTap,
    this.onImageSecondaryTap,
  }) : super(text: text);

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final String text = this.text;
    final List<InlineSpan> children = [];

    // 延迟销毁旧的手势识别器
    if (_recognizers.isNotEmpty) {
      final oldRecognizers = List<TapGestureRecognizer>.from(_recognizers);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final r in oldRecognizers) {
          r.dispose();
        }
      });
      _recognizers.clear();
    }

    // 匹配内部缓存的短 ID，例如 ![图片](img_12345)
    final RegExp imageRegExp = RegExp(r'!\[([^\]]*)\]\((img_[a-zA-Z0-9_]+)\)');

    int lastMatchEnd = 0;
    for (final Match match in imageRegExp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        final normalText = text.substring(lastMatchEnd, match.start);
        children
            .addAll(MarkdownHighlighter.highlight(normalText, context, style));
      }

      final String altText = match.group(1) ?? '';
      final String imageId = match.group(2)!;

      children.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () {
            if (onImageTap != null) {
              onImageTap!(imageId, altText);
            }
          },
          onSecondaryTapDown: (details) {
            if (onImageSecondaryTap != null) {
              onImageSecondaryTap!(imageId, details.globalPosition);
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              match.group(0)!,
              style: style?.copyWith(
                color: Colors.blue,
                fontStyle: FontStyle.italic,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ));

      final String matchText = match.group(0)!;
      if (matchText.length > 1) {
        children.add(TextSpan(
          text: matchText.substring(1),
          style: const TextStyle(
            fontSize: 0,
            height: 0,
            color: Colors.transparent,
          ),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      final normalText = text.substring(lastMatchEnd);
      children
          .addAll(MarkdownHighlighter.highlight(normalText, context, style));
    }

    return TextSpan(style: style, children: children);
  }
}
