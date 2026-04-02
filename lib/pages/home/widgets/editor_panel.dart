import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/logger.dart';
import 'markdown_controller.dart';

/**
 * 左侧编辑器面板组件
 */
class EditorPanel extends StatelessWidget {
  final bool isDark;
  final Color cardColor;
  final FocusNode focusNode;
  final MarkdownTextEditingController controller;
  final VoidCallback onPaste;
  final VoidCallback onInsertImage;
  final Map<String, String> imageBase64Cache;
  final VoidCallback onTextChanged;

  const EditorPanel({
    super.key,
    required this.isDark,
    required this.cardColor,
    required this.focusNode,
    required this.controller,
    required this.onPaste,
    required this.onInsertImage,
    required this.imageBase64Cache,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
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
      child: KeyboardListener(
        focusNode: focusNode,
        onKeyEvent: (KeyEvent event) {
          try {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.keyV) {
              if (HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed) {
                onPaste();
              }
            }
          } catch (e) {
            Logger.error('键盘事件处理异常', e);
          }
        },
        child: TextField(
          controller: controller,
          maxLines: null,
          expands: true,
          style: const TextStyle(
              fontFamily: 'Consolas', fontSize: 15, height: 1.6),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: '在此输入 Markdown 内容...',
          ),
          onChanged: (text) {
            final RegExp base64RegExp =
                RegExp(r'!\[([^\]]*)\]\((data:image\/[^;]+;base64,[^\)]+)\)');
            if (base64RegExp.hasMatch(text)) {
              final newText = text.replaceAllMapped(base64RegExp, (match) {
                final alt = match.group(1) ?? '';
                final base64 = match.group(2)!;
                final imageId =
                    'img_${DateTime.now().millisecondsSinceEpoch}_${match.start}';
                imageBase64Cache[imageId] = base64;
                return '![$alt]($imageId)';
              });
              controller.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newText.length),
              );
            } else {
              onTextChanged();
            }
          },
          contextMenuBuilder: (context, editableTextState) {
            final List<ContextMenuButtonItem> buttonItems =
                editableTextState.contextMenuButtonItems;
            buttonItems.add(ContextMenuButtonItem(
              onPressed: () {
                onInsertImage();
                editableTextState.hideToolbar();
              },
              label: '插入图片',
            ));
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: editableTextState.contextMenuAnchors,
              buttonItems: buttonItems,
            );
          },
        ),
      ),
    );
  }
}
