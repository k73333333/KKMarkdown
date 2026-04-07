import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';

/**
 * 支持悬停展示最近打开文件列表的打开文件按钮组件
 */
class OpenFileButton extends StatefulWidget {
  final VoidCallback onOpenFile;
  final Function(String path) onOpenFileFromPath;

  const OpenFileButton({
    Key? key,
    required this.onOpenFile,
    required this.onOpenFileFromPath,
  }) : super(key: key);

  @override
  State<OpenFileButton> createState() => _OpenFileButtonState();
}

class _OpenFileButtonState extends State<OpenFileButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isHovering = false;
  bool _isMenuHovering = false;

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  /**
   * 显示悬停菜单
   */
  void _showOverlay(BuildContext context) {
    if (_overlayEntry != null) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final recentFiles = appProvider.recentFiles;

    if (recentFiles.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF252526) : Colors.white;
    final borderColor = Theme.of(context).dividerColor;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 280,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 80), // 进一步增加垂直偏移量，避免遮挡按钮及Tooltip提示文案
            child: MouseRegion(
              onEnter: (_) {
                _isMenuHovering = true;
              },
              onExit: (_) {
                _isMenuHovering = false;
                _checkAndHideOverlay();
              },
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          '最近打开的文件',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ...recentFiles.take(5).map((path) {
                        final fileName =
                            path.split(Platform.pathSeparator).last;
                        return InkWell(
                          onTap: () {
                            _hideOverlay();
                            widget.onOpenFileFromPath(path);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Icons.description_outlined,
                                    size: 16,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName,
                                        style: const TextStyle(fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        path,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withOpacity(0.6),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      const Divider(height: 1),
                      InkWell(
                        onTap: () {
                          _hideOverlay();
                          _showHistoryDialog(context, recentFiles);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              '更多',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /**
   * 检查并隐藏悬停菜单
   */
  void _checkAndHideOverlay() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isHovering && !_isMenuHovering) {
        _hideOverlay();
      }
    });
  }

  /**
   * 隐藏悬停菜单
   */
  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /**
   * 显示完整历史记录对话框
   * @param context 上下文
   * @param recentFiles 最近文件列表
   */
  void _showHistoryDialog(BuildContext context, List<String> recentFiles) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.history_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('最近打开的文件',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          contentPadding: const EdgeInsets.only(top: 16, bottom: 8),
          content: SizedBox(
            width: 500,
            height: 400,
            child: ListView.separated(
              itemCount: recentFiles.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final path = recentFiles[index];
                final fileName = path.split(Platform.pathSeparator).last;
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.description_outlined,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(fileName,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      path,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onOpenFileFromPath(path);
                  },
                  hoverColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                );
              },
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 左侧：历史记录按钮
        Padding(
          padding: const EdgeInsets.only(right: 2.0),
          child: Tooltip(
            message: '历史记录',
            child: IconButton(
              icon: Icon(Icons.history_rounded,
                  size: 20,
                  color: Theme.of(context).iconTheme.color?.withOpacity(0.8)),
              splashRadius: 20,
              onPressed: () {
                final appProvider =
                    Provider.of<AppProvider>(context, listen: false);
                _showHistoryDialog(context, appProvider.recentFiles);
              },
              hoverColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ),
        // 右侧：打开文件按钮（带悬停下拉）
        CompositedTransformTarget(
          link: _layerLink,
          child: MouseRegion(
            onEnter: (_) {
              _isHovering = true;
              _showOverlay(context);
            },
            onExit: (_) {
              _isHovering = false;
              _checkAndHideOverlay();
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 2.0, right: 4.0),
              child: Tooltip(
                message: '打开文件',
                child: IconButton(
                  icon: Icon(Icons.folder_open_rounded,
                      size: 20,
                      color:
                          Theme.of(context).iconTheme.color?.withOpacity(0.8)),
                  splashRadius: 20,
                  onPressed: widget.onOpenFile,
                  hoverColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
