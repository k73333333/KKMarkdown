import 'package:flutter/material.dart';

/**
 * 极简 Markdown 语法高亮解析器
 * 使用正则表达式提取 Markdown 基础语法，并转换为带有对应样式的 TextSpan
 */
class MarkdownHighlighter {
  // 匹配常见的 Markdown 块级与行内元素
  static final RegExp _mdRegex = RegExp(
    r'(^#{1,6}\s+.*$)|' // 标题 (group 1)
    r'(```[\s\S]*?```)|' // 代码块 (group 2)
    r'(`[^`\n]+`)|' // 行内代码 (group 3)
    r'(\*\*.*?\*\*|__.*?__)|' // 粗体 (group 4)
    r'(\*[^*]+?\*|_[^_]+?_)|' // 斜体 (group 5)
    r'(^>.*$)|' // 引用 (group 6)
    r'(\[.*?\]\(.*?\))', // 链接 (group 7)
    multiLine: true,
  );

  // 代码块内部的词法解析器（用于代码高亮）
  static final RegExp _codeRegex = RegExp(
    r'(//.*$)|' // 单行注释 (group 1)
            r'(/\*[\s\S]*?\*/)|' // 多行注释 (group 2)
            r'("(?:\\.|[^"\\])*"|' +
        r"'(?:\\.|[^'\\])*')|" // 字符串 (group 3)，使用字符串拼接避免单引号在原始字符串中转义混乱
            r'(\b(?:void|bool|int|double|String|var|final|const|if|else|for|while|do|switch|case|break|continue|return|class|enum|extends|implements|with|this|super|new|try|catch|finally|throw|async|await|yield|import|export|part|library|function|let|const|null|true|false|undefined)\b)|' // 关键字 (group 4)
            r'(\b\d+(?:\.\d+)?\b)|' // 数字 (group 5)
            r'(\b[A-Z][a-zA-Z0-9_]*\b)', // 类名/类型 (首字母大写) (group 6)
    multiLine: true,
  );

  /**
   * 将普通字符串解析为带有样式的高亮 TextSpan 列表
   * @param text 待解析文本
   * @param context BuildContext 用于获取当前主题颜色
   * @param baseStyle 基础文本样式
   */
  static List<InlineSpan> highlight(
      String text, BuildContext context, TextStyle? baseStyle) {
    final List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 代码背景色适配明暗主题
    final codeBackgroundColor = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);

    for (final Match match in _mdRegex.allMatches(text)) {
      // 提取两个匹配项之间的普通文本
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      final String matchText = match.group(0)!;

      // 根据命中的具体捕获组（按照正则中的顺序），分配对应的样式
      if (match.group(1) != null) {
        // 命中标题
        int level = 0;
        while (level < matchText.length && matchText[level] == '#') {
          level++;
        }
        double size = baseStyle?.fontSize ?? 14.0;
        size += (6 - level) * 2.5; // H1 最大，H6 最小

        spans.add(TextSpan(
          text: matchText,
          style: baseStyle?.copyWith(
            fontSize: size,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary, // 使用主题色
          ),
        ));
      } else if (match.group(2) != null) {
        // 命中多行代码块
        spans.add(TextSpan(
          style: baseStyle?.copyWith(
            fontFamily: 'Consolas', // 等宽字体
            backgroundColor: codeBackgroundColor,
          ),
          children: _highlightCodeBlock(matchText, theme, baseStyle),
        ));
      } else if (match.group(3) != null) {
        // 命中行内代码
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle?.copyWith(
            fontFamily: 'Consolas', // 等宽字体
            color: colorScheme.secondary,
            backgroundColor: codeBackgroundColor,
          ),
        ));
      } else if (match.group(4) != null) {
        // 命中粗体
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (match.group(5) != null) {
        // 命中斜体
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (match.group(6) != null) {
        // 命中引用
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle?.copyWith(
            color: theme.hintColor,
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (match.group(7) != null) {
        // 命中链接
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle?.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
        ));
      } else {
        // Fallback
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle,
        ));
      }

      lastMatchEnd = match.end;
    }

    // 补充结尾的普通文本
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return spans;
  }

  /**
   * 对代码块内部进行语法高亮词法分析
   */
  static List<InlineSpan> _highlightCodeBlock(
      String text, ThemeData theme, TextStyle? baseStyle) {
    final List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    final isDark = theme.brightness == Brightness.dark;

    // 定义不同元素的颜色
    final commentColor = isDark ? Colors.green[300] : Colors.green[700];
    final stringColor = isDark ? Colors.orange[300] : Colors.orange[800];
    final keywordColor = isDark ? Colors.blue[300] : Colors.blue[700];
    final numberColor = isDark ? Colors.purple[300] : Colors.purple[700];
    final classColor = isDark ? Colors.teal[300] : Colors.teal[700];
    final defaultColor = isDark ? Colors.grey[300] : Colors.grey[800];

    for (final Match match in _codeRegex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle?.copyWith(color: defaultColor),
        ));
      }

      final String matchText = match.group(0)!;

      if (match.group(1) != null || match.group(2) != null) {
        // 注释
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle?.copyWith(
              color: commentColor, fontStyle: FontStyle.italic),
        ));
      } else if (match.group(3) != null) {
        // 字符串
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle?.copyWith(color: stringColor),
        ));
      } else if (match.group(4) != null) {
        // 关键字
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle?.copyWith(
              color: keywordColor, fontWeight: FontWeight.bold),
        ));
      } else if (match.group(5) != null) {
        // 数字
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle?.copyWith(color: numberColor),
        ));
      } else if (match.group(6) != null) {
        // 类名/类型
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle?.copyWith(color: classColor),
        ));
      } else {
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle?.copyWith(color: defaultColor),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle?.copyWith(color: defaultColor),
      ));
    }

    return spans;
  }
}
