import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/**
 * 图片预览和 Base64 查看弹窗组件
 */
class ImagePreviewDialog extends StatefulWidget {
  final String imageId;
  final String altText;
  final Map<String, String> imageBase64Cache;

  const ImagePreviewDialog({
    super.key,
    required this.imageId,
    required this.altText,
    required this.imageBase64Cache,
  });

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  bool _showBase64 = false;

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.imageBase64Cache[widget.imageId] ?? widget.imageId;
    final bool isBase64 = imageUrl.startsWith('data:image');

    String displayUrl = imageUrl;
    if (isBase64 && imageUrl.length > 500) {
      final buffer = StringBuffer();
      for (int i = 0; i < imageUrl.length; i += 100) {
        int end = i + 100;
        if (end > imageUrl.length) end = imageUrl.length;
        buffer.writeln(imageUrl.substring(i, end));
      }
      displayUrl = buffer.toString();
    }

    final TextEditingController sourceController =
        TextEditingController(text: displayUrl);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Row(
        children: [
          Icon(Icons.image_outlined,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            widget.altText.isNotEmpty ? widget.altText : '图片预览',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 800,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBase64)
              Expanded(
                flex: _showBase64 ? 1 : 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _showBase64 ? null : 0,
                  child: _showBase64
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Base64 源码',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                TextButton.icon(
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('复制全部'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: imageUrl));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('已复制 Base64 数据')),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF1E1E1E)
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .dividerColor
                                          .withOpacity(0.1)),
                                ),
                                child: TextField(
                                  controller: sourceController,
                                  maxLines: null,
                                  expands: true,
                                  style: const TextStyle(
                                      fontFamily: 'Consolas',
                                      fontSize: 12,
                                      height: 1.5),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  readOnly: true,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            if (isBase64 && _showBase64) const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxHeight: 450),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFF5F5F5),
                      border: Border.all(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: isBase64
                        ? Image.memory(
                            base64Decode(imageUrl.split(',').last),
                            fit: BoxFit.contain,
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                          ),
                  ),
                  if (isBase64) ...[
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      icon: Icon(
                          _showBase64
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18),
                      label:
                          Text(_showBase64 ? '收起 Base64 源码' : '查看 Base64 源码'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _showBase64 = !_showBase64;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/**
 * 拖拽分割线组件
 */
class DragSplitter extends StatelessWidget {
  final BoxConstraints constraints;
  final ValueChanged<double> onDrag;
  final bool isDark;

  const DragSplitter({
    super.key,
    required this.constraints,
    required this.onDrag,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (details) {
        onDrag(details.delta.dx / constraints.maxWidth);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: SizedBox(
          width: 16,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
