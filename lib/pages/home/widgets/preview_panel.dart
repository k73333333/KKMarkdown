import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../utils/logger.dart';
import '../../settings/settings_page.dart';

/**
 * 右侧预览面板组件
 */
class PreviewPanel extends StatefulWidget {
  final bool isDark;
  final Color cardColor;
  final bool isTocExpanded;
  final VoidCallback onToggleToc;
  final TocController tocController;
  final String text;
  final Map<String, String> imageBase64Cache;
  final void Function(String imageId, String altText) onShowImagePreview;
  final void Function(String text) onTranslate;
  final void Function(String text) onSpeak;

  const PreviewPanel({
    super.key,
    required this.isDark,
    required this.cardColor,
    required this.isTocExpanded,
    required this.onToggleToc,
    required this.tocController,
    required this.text,
    required this.imageBase64Cache,
    required this.onShowImagePreview,
    required this.onTranslate,
    required this.onSpeak,
  });

  @override
  State<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<PreviewPanel> {
  final TextEditingController _tocSearchController = TextEditingController();

  void _updateSearchKeyword() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tocSearchController.addListener(_updateSearchKeyword);
  }

  @override
  void dispose() {
    _tocSearchController.removeListener(_updateSearchKeyword);
    _tocSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;
    return Container(
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: SelectionArea(
        contextMenuBuilder: (BuildContext context,
            SelectableRegionState selectableRegionState) {
          final appProvider = Provider.of<AppProvider>(context, listen: false);
          final providerName = appProvider.selectedProvider;
          final configs = appProvider.translationConfigs;
          final currentConfig = configs.firstWhere(
              (c) => c.provider == providerName,
              orElse: () => configs.first);

          bool isApiValid = currentConfig.apiKey.isNotEmpty;
          if (providerName == 'baidu') {
            isApiValid = currentConfig.apiKey.isNotEmpty &&
                currentConfig.appId != null &&
                currentConfig.appId!.isNotEmpty;
          }

          final buttonItems = selectableRegionState.contextMenuButtonItems;
          if (appProvider.showTranslationButton) {
            buttonItems.add(ContextMenuButtonItem(
              onPressed: () async {
                if (!isApiValid) {
                  _showApiConfigWarning(
                      context, '当前翻译服务未配置 API Key 或 App ID，请前往设置进行配置。');
                  selectableRegionState.hideToolbar();
                  return;
                }

                // 对于某些低版本的 Flutter，获取 selectionDelegates 可能会报错
                // 所以我们通过系统提供的复制操作的回调来间接拦截并获取文本
                String originalText = '';
                try {
                  // 对于复杂的 SelectableRegion，textEditingValue 经常无法拿到完整文本
                  // 我们通过主动调用 copy() 来触发底层的获取机制，然后从剪贴板读取，再恢复剪贴板
                  final oldData = await Clipboard.getData(Clipboard.kTextPlain);

                  // 让系统帮我们复制选中的文本
                  selectableRegionState
                      .copySelection(SelectionChangedCause.toolbar);

                  // 等待剪贴板写入完成
                  await Future.delayed(const Duration(milliseconds: 50));

                  final newData = await Clipboard.getData(Clipboard.kTextPlain);
                  originalText = newData?.text ?? '';

                  // 恢复原来的剪贴板内容，做到无痕获取
                  if (oldData != null && oldData.text != null) {
                    await Clipboard.setData(oldData);
                  } else {
                    await Clipboard.setData(const ClipboardData(text: ''));
                  }
                } catch (e) {
                  Logger.error('获取选中文本失败', e);
                }

                final textInside = originalText
                    .replaceAll('_', '')
                    .replaceAll('*', '')
                    .replaceAll('#', '')
                    .replaceAll('`', '')
                    .replaceAll('~', '')
                    .replaceAll('>', '')
                    .replaceAll('-', '')
                    .replaceAll('+', '')
                    .trim();

                if (textInside.isNotEmpty) {
                  widget.onTranslate(textInside);
                }
                selectableRegionState.hideToolbar();
              },
              label: '翻译',
            ));
          }
          if (appProvider.showTtsButton) {
            buttonItems.add(ContextMenuButtonItem(
              onPressed: () async {
                String originalText = '';
                try {
                  // 对于复杂的 SelectableRegion，textEditingValue 经常无法拿到完整文本
                  // 我们通过主动调用 copy() 来触发底层的获取机制，然后从剪贴板读取，再恢复剪贴板
                  final oldData = await Clipboard.getData(Clipboard.kTextPlain);

                  // 让系统帮我们复制选中的文本
                  selectableRegionState
                      .copySelection(SelectionChangedCause.toolbar);

                  // 等待剪贴板写入完成
                  await Future.delayed(const Duration(milliseconds: 50));

                  final newData = await Clipboard.getData(Clipboard.kTextPlain);
                  originalText = newData?.text ?? '';

                  // 恢复原来的剪贴板内容，做到无痕获取
                  if (oldData != null && oldData.text != null) {
                    await Clipboard.setData(oldData);
                  } else {
                    await Clipboard.setData(const ClipboardData(text: ''));
                  }
                } catch (e) {
                  Logger.error('获取选中文本失败', e);
                }

                Logger.info('原始提取文本: "$originalText"');

                final textInside = originalText
                    .replaceAll('_', '')
                    .replaceAll('*', '')
                    .replaceAll('#', '')
                    .replaceAll('`', '')
                    .replaceAll('~', '')
                    .replaceAll('>', '')
                    .replaceAll('-', '')
                    .replaceAll('+', '')
                    .trim();

                Logger.info('清理后文本: "$textInside"');

                if (textInside.isNotEmpty) {
                  widget.onSpeak(textInside);
                } else {
                  Logger.info('清理后文本为空，跳过朗读');
                }
                selectableRegionState.hideToolbar();
              },
              label: '▶ 播放',
            ));
          }

          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: selectableRegionState.contextMenuAnchors,
            buttonItems: buttonItems,
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isTocExpanded)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 260,
                margin: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF252526) : Colors.white,
                  border: Border.all(color: dividerColor.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withOpacity(widget.isDark ? 0.3 : 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF2D2D30)
                            : const Color(0xFFF8F9FA),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(Icons.format_list_bulleted,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          const Text('大纲目录',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          const Spacer(),
                          IconButton(
                            tooltip: '收起目录',
                            splashRadius: 20,
                            onPressed: widget.onToggleToc,
                            icon: const Icon(Icons.chevron_left, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: dividerColor.withOpacity(0.1)),
                    // 目录搜索框
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color:
                              widget.isDark ? Colors.black26 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: dividerColor.withOpacity(0.1),
                          ),
                        ),
                        child: TextField(
                          controller: _tocSearchController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '搜索标题...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.4),
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              size: 16,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.4),
                            ),
                            suffixIcon: _tocSearchController.text.isNotEmpty
                                ? InkWell(
                                    onTap: () {
                                      _tocSearchController.clear();
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.4),
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.only(top: 8),
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: dividerColor.withOpacity(0.1)),
                    Expanded(
                      child: TocWidget(
                        controller: widget.tocController,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        itemBuilder: (data) {
                          final keyword = _tocSearchController.text.trim();
                          if (keyword.isEmpty) {
                            return null; // 无搜索词，使用默认样式并保留自动滚动
                          }

                          // 提取标题纯文本
                          String titleText =
                              _extractTextFromNode(data.toc.node);

                          // 如果有搜索词且标题不包含搜索词，则返回一个空的 widget 隐藏它
                          if (!titleText
                              .toLowerCase()
                              .contains(keyword.toLowerCase())) {
                            return const SizedBox.shrink();
                          }

                          // 匹配时，自己渲染 ListTile
                          bool isCurrentToc = data.index == data.currentIndex;

                          // 提取等级 (1~6)
                          int level = 1;
                          final tag = data.toc.node.headingConfig.tag;
                          if (tag.startsWith('h') && tag.length == 2) {
                            level = int.tryParse(tag.substring(1)) ?? 1;
                          }

                          return ListTile(
                            title: Container(
                              margin: EdgeInsets.only(left: 20.0 * level),
                              child: _buildHighlightedText(
                                  titleText, keyword, context, isCurrentToc),
                            ),
                            onTap: () {
                              widget.tocController
                                  .jumpToIndex(data.toc.widgetIndex);
                              data.refreshIndexCallback(data.index);
                            },
                          );
                        },
                        tocTextStyle: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.7),
                        ),
                        currentTocTextStyle: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Tooltip(
                    message: '展开目录',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.onToggleToc,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.cardColor,
                          border:
                              Border.all(color: dividerColor.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.format_list_bulleted,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: widget.cardColor,
                  border: Border.all(color: dividerColor.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withOpacity(widget.isDark ? 0.3 : 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MarkdownWidget(
                    data: widget.text,
                    tocController: widget.tocController,
                    selectable: false,
                    config: (widget.isDark
                            ? MarkdownConfig.darkConfig
                            : MarkdownConfig.defaultConfig)
                        .copy(configs: [
                      PConfig(
                        textStyle: TextStyle(
                          color: widget.isDark
                              ? const Color(0xFFD4D4D4)
                              : const Color(0xFF333333),
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      CodeConfig(
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Consolas',
                          color: widget.isDark
                              ? const Color(0xFFCE9178)
                              : const Color(0xFF0000FF),
                        ),
                      ),
                      PreConfig(
                        theme: widget.isDark
                            ? _atomOneDarkTheme()
                            : _atomOneLightTheme(),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Consolas',
                        ),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? const Color(0xFF1E1E1E)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: dividerColor.withOpacity(0.1)),
                        ),
                        padding: const EdgeInsets.all(16),
                      ),
                      BlockquoteConfig(
                        textColor: widget.isDark
                            ? const Color(0xFF9CDCFE)
                            : const Color(0xFF666666),
                      ),
                      LinkConfig(
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        onTap: (url) {
                          // TODO: 处理链接点击
                        },
                      ),
                      ImgConfig(builder:
                          (String imageUrl, Map<String, String> attributes) {
                        String imageId = imageUrl;
                        if (imageUrl.startsWith('img_')) {
                          imageUrl =
                              widget.imageBase64Cache[imageUrl] ?? imageUrl;
                        }
                        final alt = attributes['alt'] ?? '';
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              widget.onShowImagePreview(imageId, alt);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: imageUrl.startsWith('data:image')
                                  ? Image.memory(
                                      base64Decode(imageUrl.split(',').last))
                                  : Image.network(imageUrl),
                            ),
                          ),
                        );
                      })
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Atom One Dark 主题
  Map<String, TextStyle> _atomOneDarkTheme() {
    return {
      'root': const TextStyle(
          color: Color(0xffabb2bf), backgroundColor: Color(0xff282c34)),
      'keyword': const TextStyle(color: Color(0xffc678dd)),
      'built_in': const TextStyle(color: Color(0xffe6c07b)),
      'type': const TextStyle(color: Color(0xffe6c07b)),
      'literal': const TextStyle(color: Color(0xff56b6c2)),
      'number': const TextStyle(color: Color(0xffd19a66)),
      'string': const TextStyle(color: Color(0xff98c379)),
      'regexp': const TextStyle(color: Color(0xff98c379)),
      'comment': const TextStyle(
          color: Color(0xff5c6370), fontStyle: FontStyle.italic),
      'symbol': const TextStyle(color: Color(0xff61aeee)),
      'class': const TextStyle(color: Color(0xffe6c07b)),
      'function': const TextStyle(color: Color(0xff61aeee)),
      'title': const TextStyle(color: Color(0xff61aeee)),
      'params': const TextStyle(color: Color(0xffabb2bf)),
      'meta': const TextStyle(color: Color(0xff61aeee)),
      'variable': const TextStyle(color: Color(0xffe06c75)),
      'attribute': const TextStyle(color: Color(0xffd19a66)),
      'doctag': const TextStyle(color: Color(0xffc678dd)),
      'section': const TextStyle(
          color: Color(0xffe06c75), fontWeight: FontWeight.bold),
      'strong': const TextStyle(fontWeight: FontWeight.bold),
      'emphasis': const TextStyle(fontStyle: FontStyle.italic),
      'bullet': const TextStyle(color: Color(0xffd19a66)),
      'code': const TextStyle(color: Color(0xff98c379)),
      'addition': const TextStyle(color: Color(0xff98c379)),
      'deletion': const TextStyle(color: Color(0xffe06c75)),
    };
  }

  // Atom One Light 主题
  Map<String, TextStyle> _atomOneLightTheme() {
    return {
      'root': const TextStyle(
          color: Color(0xff383a42), backgroundColor: Color(0xfffafafa)),
      'keyword': const TextStyle(color: Color(0xffa626a4)),
      'built_in': const TextStyle(color: Color(0xffc18401)),
      'type': const TextStyle(color: Color(0xffc18401)),
      'literal': const TextStyle(color: Color(0xff0184bc)),
      'number': const TextStyle(color: Color(0xff986801)),
      'string': const TextStyle(color: Color(0xff50a14f)),
      'regexp': const TextStyle(color: Color(0xff50a14f)),
      'comment': const TextStyle(
          color: Color(0xffa0a1a7), fontStyle: FontStyle.italic),
      'symbol': const TextStyle(color: Color(0xff4078f2)),
      'class': const TextStyle(color: Color(0xffc18401)),
      'function': const TextStyle(color: Color(0xff4078f2)),
      'title': const TextStyle(color: Color(0xff4078f2)),
      'params': const TextStyle(color: Color(0xff383a42)),
      'meta': const TextStyle(color: Color(0xff4078f2)),
      'variable': const TextStyle(color: Color(0xffe45649)),
      'attribute': const TextStyle(color: Color(0xff986801)),
      'doctag': const TextStyle(color: Color(0xffa626a4)),
      'section': const TextStyle(
          color: Color(0xffe45649), fontWeight: FontWeight.bold),
      'strong': const TextStyle(fontWeight: FontWeight.bold),
      'emphasis': const TextStyle(fontStyle: FontStyle.italic),
      'bullet': const TextStyle(color: Color(0xff986801)),
      'code': const TextStyle(color: Color(0xff50a14f)),
      'addition': const TextStyle(color: Color(0xff50a14f)),
      'deletion': const TextStyle(color: Color(0xffe45649)),
    };
  }

  void _showApiConfigWarning(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  // 辅助方法：提取节点的纯文本
  String _extractTextFromNode(SpanNode node) {
    if (node is TextNode) {
      return node.text;
    } else if (node is ElementNode) {
      return node.children.map((child) => _extractTextFromNode(child)).join('');
    }
    return '';
  }

  // 辅助方法：构建搜索关键字高亮的文本
  Widget _buildHighlightedText(
      String text, String keyword, BuildContext context, bool isCurrent) {
    final defaultStyle = TextStyle(
      fontSize: 13,
      height: 1.5,
      color: isCurrent
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
    );

    if (keyword.isEmpty) {
      return Text(text, style: defaultStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();

    List<TextSpan> spans = [];
    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = lowerText.indexOf(lowerKeyword, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      }

      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + keyword.length),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ));

      start = indexOfMatch + keyword.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      text: TextSpan(
        style: defaultStyle,
        children: spans,
      ),
    );
  }
}

class _ImageErrorWidget extends StatelessWidget {
  const _ImageErrorWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D30)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 32,
            color: Theme.of(context).dividerColor.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            '图片加载失败',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
