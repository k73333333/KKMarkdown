import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import '../providers/app_provider.dart';
import '../api/translation_manager.dart';
import '../utils/logger.dart';
import '../utils/markdown_highlighter.dart';
import 'settings_page.dart';

/**
 * 主页
 * 包含 Markdown 编辑区和预览区 
 */
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/** 视图模式枚举 */
enum ViewMode {
  /** 仅编辑 */
  edit,
  /** 双屏预览（同时编辑和预览） */
  split,
  /** 仅预览 */
  preview,
}

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

    // 延迟销毁旧的手势识别器，避免在 Flutter 渲染管线中还在使用时被销毁，导致 'attached': is not true 断言异常
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
      // 添加匹配前的普通文本（交给语法高亮解析器处理）
      if (match.start > lastMatchEnd) {
        final normalText = text.substring(lastMatchEnd, match.start);
        children
            .addAll(MarkdownHighlighter.highlight(normalText, context, style));
      }

      final String altText = match.group(1) ?? '图片';
      final String imageId = match.group(2)!;

      // 渲染为 WidgetSpan 以彻底避免 TextSpan 中使用 recognizer 导致的生命周期问题
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

      // 插入与 WidgetSpan 对应的不可见文本，保持 EditableText 内部光标计算的文本长度一致
      // 这里的占位符文本长度等于 match.group(0) 的长度减去 1（WidgetSpan 占了 1 个长度）
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

    // 添加剩余的文本（交给语法高亮解析器处理）
    if (lastMatchEnd < text.length) {
      final normalText = text.substring(lastMatchEnd);
      children
          .addAll(MarkdownHighlighter.highlight(normalText, context, style));
    }

    return TextSpan(style: style, children: children);
  }
}

class _HomePageState extends State<HomePage> with WindowListener {
  /** 当前的视图模式 */
  ViewMode _viewMode = ViewMode.split;

  final TocController _tocController = TocController();

  bool _isTocExpanded = false;

  /** 窗口是否最大化 */
  bool _isMaximized = false;

  /** 窗口是否全屏 */
  bool _isFullScreen = false;

  /** 双屏模式下左侧编辑区占据的宽度比例（0.1 到 0.9 之间） */
  double _editAreaRatio = 0.5;

  /** Markdown 文本内容 */
  late final MarkdownTextEditingController _controller;

  /** 文本转语音实例 */
  final FlutterTts _flutterTts = FlutterTts();

  /** 翻译服务管理器实例 */
  final TranslationManager _translationManager = TranslationManager();

  /** 编辑器焦点节点 */
  final FocusNode _focusNode = FocusNode();

  /** 图片 Base64 缓存，用于避免编辑器处理超大字符串导致卡顿和布局崩溃 */
  final Map<String, String> _imageBase64Cache = {};

  @override
  void initState() {
    super.initState();
    _controller = MarkdownTextEditingController(
      onImageTap: (imageId, altText) {
        _showImagePreviewDialog(imageId, altText);
      },
      onImageSecondaryTap: (imageId, position) {
        _showDeleteImageMenu(imageId, position);
      },
    );
    // 初始化 TTS
    _initTts();
    // 设置默认示例文本
    _controller.text = '# 欢迎使用 KKMarkdown\n\n这是一个 Markdown 编辑器。';

    // 监听窗口最大化状态
    windowManager.addListener(this);
    _initWindowState();
  }

  Future<void> _initWindowState() async {
    bool isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        _isMaximized = isMaximized;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 动态同步系统的标题栏按钮颜色（暗色/亮色）以确保原生按钮可见
    final Brightness brightness = Theme.of(context).brightness;
    // 使用 windowManager.setBrightness 设置原生按钮的亮度，Light 则按钮为黑色，Dark 则为白色
    windowManager.setBrightness(brightness);
  }

  @override
  void onWindowMaximize() {
    setState(() {
      _isMaximized = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      _isMaximized = false;
    });
  }

  @override
  void onWindowEnterFullScreen() {
    setState(() {
      _isFullScreen = true;
    });
  }

  @override
  void onWindowLeaveFullScreen() {
    setState(() {
      _isFullScreen = false;
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _tocController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  /**
   * 将图片字节数据插入到当前光标位置
   * 将真实的 base64 存入缓存，编辑器中仅插入短 ID 占位符
   */
  void _insertImageToBase64(Uint8List imageBytes, {String extension = 'png'}) {
    final base64String =
        'data:image/$extension;base64,${base64Encode(imageBytes)}';
    final imageId = 'img_${DateTime.now().millisecondsSinceEpoch}';
    _imageBase64Cache[imageId] = base64String;

    final imageMarkdown = '![图片]($imageId)\n';

    final text = _controller.text;
    final selection = _controller.selection;

    String newText;
    int newOffset;

    if (selection.baseOffset == -1) {
      newText = text + '\n' + imageMarkdown;
      newOffset = newText.length;
    } else {
      newText =
          text.replaceRange(selection.start, selection.end, imageMarkdown);
      newOffset = selection.start + imageMarkdown.length;
    }

    // 使用 TextEditingValue 原子性更新文本和光标，避免抛出 RangeError
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );

    // 强制触发一次更新
    setState(() {});
  }

  /**
   * 处理剪贴板粘贴事件
   */
  Future<void> _handlePaste() async {
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        _insertImageToBase64(imageBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已从剪贴板粘贴图片')),
          );
        }
      }
    } catch (e) {
      Logger.error('读取剪贴板图片失败', e);
      // 防止某些系统或应用层的读取异常向上抛出
    }
  }

  /**
   * 从本地选择图片并插入
   */
  Future<void> _insertImageFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        final bytes = await file.readAsBytes();

        // 简单提取扩展名
        String ext = path.split('.').last.toLowerCase();
        if (ext == 'jpg') ext = 'jpeg';

        _insertImageToBase64(bytes, extension: ext);
      }
    } catch (e) {
      Logger.error('选择图片失败', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('插入图片失败: $e')),
        );
      }
    }
  }

  /**
   * 初始化 TTS 配置
   */
  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("zh-CN");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
    } catch (e) {
      Logger.error('TTS 初始化失败', e);
    }
  }

  /**
   * 处理文本朗读
   * @param text 待朗读文本
   */
  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      Logger.error('TTS 朗读失败', e);
    }
  }

  /**
   * 处理文本翻译
   * @param text 待翻译文本
   */
  Future<void> _translate(String text) async {
    if (text.isEmpty) return;

    // 获取翻译配置
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final providerName = appProvider.selectedProvider;
    final configs = appProvider.translationConfigs;

    // 查找当前选中的配置
    final currentConfig = configs.firstWhere(
      (c) => c.provider == providerName,
      orElse: () => configs.first,
    );

    // 校验配置是否有效
    bool isConfigValid = currentConfig.apiKey.isNotEmpty;
    if (providerName == 'baidu') {
      isConfigValid = currentConfig.apiKey.isNotEmpty &&
          currentConfig.appId != null &&
          currentConfig.appId!.isNotEmpty;
    }

    if (!isConfigValid) {
      // 如果配置无效/未填写，弹出提示弹窗
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('当前翻译服务未配置 API Key 或 App ID，请前往设置进行配置。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 关闭弹窗
                // 跳转到设置页面
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
              child: const Text('前往配置'),
            ),
          ],
        ),
      );
      return; // 终止翻译流程
    }

    // 显示加载中提示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 调用翻译服务
      // 注意：这里需要确保 AppProvider 中的配置已同步到 TranslationManager
      // 实际项目中应通过 Provider 获取配置并传递给 Manager
      final result = await _translationManager.translate(text);

      if (!mounted) return;
      Navigator.pop(context); // 关闭加载框

      // 显示翻译结果弹窗
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('翻译结果'),
          content: SingleChildScrollView(
            child: Text(result),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('复制'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      Logger.error('翻译操作失败', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('翻译失败: $e')),
      );
    }
  }

  /**
   * 打开文件
   */
  Future<void> _openFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        String content = await file.readAsString();

        // 提取文件中所有的 base64 图片到缓存中，保持编辑器文本简短
        final RegExp base64RegExp =
            RegExp(r'!\[([^\]]*)\]\((data:image\/[^;]+;base64,[^\)]+)\)');
        content = content.replaceAllMapped(base64RegExp, (match) {
          final alt = match.group(1) ?? '图片';
          final base64 = match.group(2)!;
          final imageId =
              'img_${DateTime.now().millisecondsSinceEpoch}_${match.start}';
          _imageBase64Cache[imageId] = base64;
          return '![$alt]($imageId)';
        });

        setState(() {
          _controller.text = content;
        });

        if (mounted) {
          Provider.of<AppProvider>(context, listen: false)
              .setCurrentFilePath(path);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件读取成功')),
          );
        }
      }
    } catch (e) {
      Logger.error('打开文件失败', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开文件失败: $e')),
        );
      }
    }
  }

  /**
   * 获取替换回真实 Base64 后的完整文本用于保存
   */
  String _getContentToSave() {
    String contentToSave = _controller.text;
    final RegExp imgIdRegExp = RegExp(r'!\[([^\]]*)\]\((img_[a-zA-Z0-9_]+)\)');
    contentToSave = contentToSave.replaceAllMapped(imgIdRegExp, (match) {
      final alt = match.group(1) ?? '图片';
      final imageId = match.group(2)!;
      final base64 = _imageBase64Cache[imageId];
      if (base64 != null) {
        return '![$alt]($base64)';
      }
      return match.group(0)!; // 缓存丢失则保持原样
    });
    return contentToSave;
  }

  /**
   * 保存文件
   */
  Future<void> _saveFile() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final currentPath = appProvider.currentFilePath;

    if (currentPath != null && currentPath.isNotEmpty) {
      try {
        final file = File(currentPath);
        await file.writeAsString(_getContentToSave());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存成功')),
          );
        }
      } catch (e) {
        Logger.error('保存文件失败', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存文件失败: $e')),
          );
        }
      }
    } else {
      // 当前没有打开的文件，执行另存为
      await _saveAsFile();
    }
  }

  /**
   * 另存为文件
   */
  Future<void> _saveAsFile() async {
    try {
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '另存为',
        fileName: '未命名.md',
        type: FileType.custom,
        allowedExtensions: ['md', 'txt'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(_getContentToSave());

        if (mounted) {
          Provider.of<AppProvider>(context, listen: false)
              .setCurrentFilePath(outputFile);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存成功')),
          );
        }
      }
    } catch (e) {
      Logger.error('另存为失败', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('另存为失败: $e')),
        );
      }
    }
  }

  /**
   * 显示删除图片的右键菜单
   */
  void _showDeleteImageMenu(String imageId, Offset position) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final result = await showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('删除图片', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );

    if (result == 'delete' && mounted) {
      final text = _controller.text;
      // 查找该图片占位符
      final RegExp regExp = RegExp(r'!\[([^\]]*)\]\(' + imageId + r'\)');
      final match = regExp.firstMatch(text);
      if (match != null) {
        final newText = text.replaceRange(match.start, match.end, '');

        int newOffset = _controller.selection.baseOffset;
        if (newOffset > match.end) {
          newOffset -= (match.end - match.start);
        } else if (newOffset > match.start) {
          newOffset = match.start;
        }

        // 使用 TextEditingValue 原子性更新文本和光标
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newOffset),
        );

        setState(() {});

        _imageBase64Cache.remove(imageId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片已删除')),
        );
      }
    }
  }

  /**
   * 显示图片预览和 Base64 查看弹窗
   */
  void _showImagePreviewDialog(String imageId, String altText) {
    final imageUrl = _imageBase64Cache[imageId] ?? imageId; // 获取真实 base64
    final bool isBase64 = imageUrl.startsWith('data:image');

    // 优化性能 1：将超长无空格的 Base64 字符串强制换行，避免 Flutter 文本排版引擎（HarfBuzz）计算单行超长文本导致严重卡顿
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

    // 优化性能 2：提前初始化 Controller，避免在弹窗更新（StatefulBuilder 动画）时反复创建和解析超长文本
    final TextEditingController sourceController =
        TextEditingController(text: displayUrl);

    showDialog(
      context: context,
      builder: (context) {
        bool showBase64 = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(altText.isNotEmpty ? altText : '图片详情'),
              content: SizedBox(
                width: 800,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左侧：Base64 数据展示/编辑区 (可折叠)
                    if (isBase64)
                      Expanded(
                        flex: showBase64 ? 1 : 0,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: showBase64 ? null : 0,
                          child: showBase64
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Base64 数据:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: sourceController,
                                        maxLines: null,
                                        expands: true,
                                        style: const TextStyle(
                                            fontFamily: 'Consolas',
                                            fontSize: 12),
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.all(8),
                                        ),
                                        readOnly: true,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.copy, size: 16),
                                      label: const Text('复制全部'),
                                      onPressed: () {
                                        Clipboard.setData(
                                            ClipboardData(text: imageUrl));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('已复制 Base64 数据')),
                                        );
                                      },
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),

                    if (isBase64 && showBase64) const SizedBox(width: 16),

                    // 右侧：图片预览区
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxHeight: 400),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(8),
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
                            const SizedBox(height: 16),
                            TextButton.icon(
                              icon: Icon(showBase64
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              label: Text(
                                  showBase64 ? '收起 Base64 源码' : '查看 Base64 源码'),
                              onPressed: () {
                                setState(() {
                                  showBase64 = !showBase64;
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
          },
        );
      },
    ).then((_) {
      // 弹窗关闭后释放内存
      sourceController.dispose();
    });
  }

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

  /**
   * 构建左侧编辑器面板
   */
  Widget _buildEditorPanel(BuildContext context, bool isDark, Color cardColor) {
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
        focusNode: _focusNode,
        onKeyEvent: (KeyEvent event) {
          try {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.keyV) {
              if (HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed) {
                _handlePaste();
              }
            }
          } catch (e) {
            Logger.error('键盘事件处理异常', e);
          }
        },
        child: TextField(
          controller: _controller,
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
                RegExp(r'!\[([^\]]*)\]\((data:image/[^;]+;base64,[^\)]+)\)');
            if (base64RegExp.hasMatch(text)) {
              final newText = text.replaceAllMapped(base64RegExp, (match) {
                final alt = match.group(1) ?? '图片';
                final base64 = match.group(2)!;
                final imageId =
                    'img_${DateTime.now().millisecondsSinceEpoch}_${match.start}';
                _imageBase64Cache[imageId] = base64;
                return '![$alt]($imageId)';
              });
              _controller.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newText.length),
              );
            } else {
              setState(() {});
            }
          },
          contextMenuBuilder: (context, editableTextState) {
            final List<ContextMenuButtonItem> buttonItems =
                editableTextState.contextMenuButtonItems;
            buttonItems.add(ContextMenuButtonItem(
              onPressed: () {
                _insertImageFromFile();
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

  /**
   * 构建拖拽分割线
   */
  Widget _buildSplitter(BoxConstraints constraints, bool isDark) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (details) {
        setState(() {
          _editAreaRatio += details.delta.dx / constraints.maxWidth;
          _editAreaRatio = _editAreaRatio.clamp(0.1, 0.9);
        });
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

  /**
   * 构建右侧预览面板
   */
  Widget _buildPreviewPanel(
      BuildContext context, bool isDark, Color cardColor) {
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
            if (_isTocExpanded)
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
                            onPressed: () {
                              setState(() {
                                _isTocExpanded = false;
                              });
                            },
                            icon: const Icon(Icons.chevron_left, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: dividerColor.withOpacity(0.1)),
                    Expanded(
                      child: TocWidget(
                        controller: _tocController,
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
                      onTap: () {
                        setState(() {
                          _isTocExpanded = true;
                        });
                      },
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
                data: _controller.text,
                tocController: _tocController,
                selectable: false,
                config: (isDark
                        ? MarkdownConfig.darkConfig
                        : MarkdownConfig.defaultConfig)
                    .copy(configs: [
                  ImgConfig(builder:
                      (String imageUrl, Map<String, String> attributes) {
                    String imageId = imageUrl;
                    if (imageUrl.startsWith('img_')) {
                      imageUrl = _imageBase64Cache[imageUrl] ?? imageUrl;
                    }
                    final alt = attributes['alt'] ?? '图片';
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          _showImagePreviewDialog(imageId, alt);
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
              onPressed: () {
                if (!isApiValid) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('提示'),
                      content:
                          const Text('当前翻译服务未配置 API Key 或 App ID，请前往设置进行配置。'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsPage()));
                          },
                          child: const Text('前往配置'),
                        ),
                      ],
                    ),
                  );
                  selectableRegionState.hideToolbar();
                  return;
                }
                final text = selectableRegionState.textEditingValue.selection
                    .textInside(selectableRegionState.textEditingValue.text);
                _translate(text);
                selectableRegionState.hideToolbar();
              },
              label: '翻译',
            ));
          }
          if (appProvider.showTtsButton) {
            buttonItems.add(ContextMenuButtonItem(
              onPressed: () {
                if (!isApiValid) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('提示'),
                      content: const Text('使用文本朗读功能前，请前往设置配置 API Key。'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsPage()));
                          },
                          child: const Text('前往配置'),
                        ),
                      ],
                    ),
                  );
                  selectableRegionState.hideToolbar();
                  return;
                }
                final text = selectableRegionState.textEditingValue.selection
                    .textInside(selectableRegionState.textEditingValue.text);
                _speak(text);
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        final currentFile = appProvider.currentFilePath;
        final fileName = currentFile != null
            ? currentFile.split(Platform.pathSeparator).last
            : '未命名';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // 优化背景色与面板色，增强层次感
        final bgColor =
            isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F2F5);
        final cardColor = isDark ? const Color(0xFF252526) : Colors.white;
        final dividerColor = Theme.of(context).dividerColor;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: GestureDetector(
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
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                actions: [
                  _buildToolbarButton(
                      context, Icons.folder_open_rounded, '打开文件', _openFile),
                  _buildToolbarButton(
                      context, Icons.save_rounded, '保存', _saveFile),
                  _buildToolbarButton(
                      context, Icons.save_as_rounded, '另存为', _saveAsFile),

                  Container(
                    margin:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
                        fillColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.15),
                        selectedColor: Theme.of(context).colorScheme.primary,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        constraints:
                            const BoxConstraints(minHeight: 36, minWidth: 42),
                        isSelected: [
                          _viewMode == ViewMode.edit,
                          _viewMode == ViewMode.split,
                          _viewMode == ViewMode.preview,
                        ],
                        onPressed: (int index) {
                          setState(() {
                            if (index == 0) _viewMode = ViewMode.edit;
                            if (index == 1) _viewMode = ViewMode.split;
                            if (index == 2) _viewMode = ViewMode.preview;
                          });
                        },
                        children: const [
                          Tooltip(
                              message: '仅编辑',
                              child: Icon(Icons.edit_outlined, size: 18)),
                          Tooltip(
                              message: '双屏预览',
                              child: Icon(Icons.vertical_split_outlined,
                                  size: 18)),
                          Tooltip(
                              message: '仅预览',
                              child: Icon(Icons.visibility_outlined, size: 18)),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    margin:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    width: 1,
                    color: dividerColor.withOpacity(0.3),
                  ),

                  _buildToolbarButton(context, Icons.settings_outlined, '设置',
                      () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SettingsPage()));
                  }),

                  const SizedBox(width: 8),

                  // Window controls
                  _buildWindowButton(context, Icons.minimize, '最小化',
                      () => windowManager.minimize()),
                  _buildWindowButton(
                    context,
                    _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    _isFullScreen ? '退出全屏' : '全屏',
                    () async {
                      windowManager.setFullScreen(!_isFullScreen);
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
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    if (_viewMode == ViewMode.edit ||
                        _viewMode == ViewMode.split)
                      SizedBox(
                        width: _viewMode == ViewMode.split
                            ? constraints.maxWidth * _editAreaRatio - 8
                            : constraints.maxWidth,
                        child: _buildEditorPanel(context, isDark, cardColor),
                      ),
                    if (_viewMode == ViewMode.split)
                      _buildSplitter(constraints, isDark),
                    if (_viewMode == ViewMode.preview ||
                        _viewMode == ViewMode.split)
                      Expanded(
                        child: _buildPreviewPanel(context, isDark, cardColor),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
