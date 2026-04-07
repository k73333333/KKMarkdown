import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../settings/settings_page.dart';
import '../view_mode.dart';
import 'open_file_button.dart';

/**
 * 顶部工具栏组件
 */
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String fileName;
  final bool isDark;
  final Color cardColor;
  final Color dividerColor;
  final ViewMode viewMode;
  final bool isFullScreen; // 窗口是否处于全屏状态
  final bool isMaximized; // 窗口是否处于最大化状态
  final VoidCallback onOpenFile; // 打开文件回调
  final Function(String path) onOpenFileFromPath; // 从指定路径打开文件回调
  final VoidCallback onSaveFile;
  final VoidCallback onSaveAsFile;
  final ValueChanged<ViewMode> onViewModeChanged;

  const HomeAppBar({
    super.key,
    required this.fileName,
    required this.isDark,
    required this.cardColor,
    required this.dividerColor,
    required this.viewMode,
    required this.isFullScreen,
    required this.isMaximized,
    required this.onOpenFile,
    required this.onOpenFileFromPath,
    required this.onSaveFile,
    required this.onSaveAsFile,
    required this.onViewModeChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  /**
   * 构建工具栏按钮
   */
  Widget _buildToolbarButton(BuildContext context, IconData icon,
      String tooltip, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon,
              size: 20,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.8)),
          splashRadius: 20,
          onPressed: onPressed,
          hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
      ),
    );
  }

  /**
   * 构建窗口控制按钮
   */
  Widget _buildWindowButton(BuildContext context, IconData icon, String tooltip,
      VoidCallback onPressed,
      {bool isClose = false}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        hoverColor: isClose ? Colors.red : Theme.of(context).hoverColor,
        child: SizedBox(
          width: 46,
          height: double.infinity,
          child: Icon(
            icon,
            size: 16,
            color: isClose
                ? Colors.red
                : Theme.of(context).iconTheme.color?.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Icon(Icons.edit_document,
                size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              fileName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          OpenFileButton(
            onOpenFile: onOpenFile,
            onOpenFileFromPath: onOpenFileFromPath,
          ),
          _buildToolbarButton(context, Icons.save_rounded, '保存', onSaveFile),
          _buildToolbarButton(
              context, Icons.save_as_rounded, '另存为', onSaveAsFile),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            width: 1,
            color: dividerColor.withOpacity(0.3),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ToggleButtons(
                borderRadius: BorderRadius.circular(8.0),
                borderWidth: 0,
                fillColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.15),
                selectedColor: Theme.of(context).colorScheme.primary,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                constraints: const BoxConstraints(minHeight: 36, minWidth: 42),
                isSelected: [
                  viewMode == ViewMode.edit,
                  viewMode == ViewMode.split,
                  viewMode == ViewMode.preview,
                ],
                onPressed: (int index) {
                  if (index == 0) onViewModeChanged(ViewMode.edit);
                  if (index == 1) onViewModeChanged(ViewMode.split);
                  if (index == 2) onViewModeChanged(ViewMode.preview);
                },
                children: const [
                  Tooltip(
                      message: '仅编辑',
                      child: Icon(Icons.edit_outlined, size: 18)),
                  Tooltip(
                      message: '双屏预览',
                      child: Icon(Icons.vertical_split_outlined, size: 18)),
                  Tooltip(
                      message: '仅预览',
                      child: Icon(Icons.visibility_outlined, size: 18)),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            width: 1,
            color: dividerColor.withOpacity(0.3),
          ),
          _buildToolbarButton(context, Icons.settings_outlined, '设置', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const SettingsPage()));
          }),
          const SizedBox(width: 8),
          // 窗口控制 - 全屏/退出全屏按钮
          _buildWindowButton(
            context,
            isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
            isFullScreen ? '退出全屏' : '全屏',
            () async {
              windowManager.setFullScreen(!isFullScreen);
            },
          ),
          // Window controls
          _buildWindowButton(
              context, Icons.minimize, '最小化', () => windowManager.minimize()),
          // 窗口控制 - 最大化/还原按钮
          _buildWindowButton(
            context,
            // 根据当前是否最大化状态显示不同图标
            isMaximized ? Icons.filter_none : Icons.crop_square,
            // 根据当前是否最大化状态显示不同提示文本
            isMaximized ? '向下还原' : '最大化',
            () async {
              // 点击时切换最大化/还原状态
              if (isMaximized) {
                windowManager.unmaximize();
              } else {
                windowManager.maximize();
              }
            },
          ),
          _buildWindowButton(
            context,
            Icons.close,
            '关闭',
            () => windowManager.close(),
            isClose: true,
          ),
        ],
      ),
    );
  }
}
