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
class PreviewPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: SelectionArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isTocExpanded)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 260,
                margin: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252526) : Colors.white,
                  border: Border.all(color: dividerColor.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                        color: isDark
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
                            onPressed: onToggleToc,
                            icon: const Icon(Icons.chevron_left, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: dividerColor.withOpacity(0.1)),
                    Expanded(
                      child: TocWidget(
                        controller: tocController,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
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
                      onTap: onToggleToc,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cardColor,
                          border:
                              Border.all(color: dividerColor.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
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
              child: MarkdownWidget(
                data: text,
                tocController: tocController,
                selectable: false,
                config: (isDark
                        ? MarkdownConfig.darkConfig
                        : MarkdownConfig.defaultConfig)
                    .copy(configs: [
                  ImgConfig(builder:
                      (String imageUrl, Map<String, String> attributes) {
                    String imageId = imageUrl;
                    if (imageUrl.startsWith('img_')) {
                      imageUrl = imageBase64Cache[imageUrl] ?? imageUrl;
                    }
                    final alt = attributes['alt'] ?? '';
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          onShowImagePreview(imageId, alt);
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
          ],
        ),
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
                    // 如果原来是空的，清空它
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
                  onTranslate(textInside);
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
                  onSpeak(textInside);
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
              buttonItems: buttonItems);
        },
      ),
    );
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
                  MaterialPageRoute(
                      builder: (context) => const SettingsPage()));
            },
            child: const Text('前往配置'),
          ),
        ],
      ),
    );
  }
}
