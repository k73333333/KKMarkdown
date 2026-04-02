import 'dart:io';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../providers/app_provider.dart';
import '../../../api/translation_manager.dart';
import '../../../utils/logger.dart';
import 'view_mode.dart';
import 'widgets/markdown_controller.dart';
import 'widgets/editor_panel.dart';
import 'widgets/preview_panel.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/dialogs_and_splitters.dart';
import 'logic/file_image_handler.dart';

/**
 * 主页
 * 包含 Markdown 编辑区和预览区 
 */
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WindowListener, FileAndImageHandler<HomePage> {
  ViewMode _viewMode = ViewMode.split;
  final TocController _tocController = TocController();
  bool _isTocExpanded = false;
  bool _isMaximized = false;
  bool _isFullScreen = false;
  double _editAreaRatio = 0.5;

  late final MarkdownTextEditingController _controller;
  final FlutterTts _flutterTts = FlutterTts();
  final TranslationManager _translationManager = TranslationManager();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = MarkdownTextEditingController(
      onImageTap: (imageId, altText) {
        showDialog(
          context: context,
          builder: (context) => ImagePreviewDialog(
            imageId: imageId,
            altText: altText,
            imageBase64Cache: imageBase64Cache,
          ),
        );
      },
      onImageSecondaryTap: (imageId, position) {
        _showDeleteImageMenu(imageId, position);
      },
    );
    _initTts();
    _controller.text = '# 欢迎使用 KKMarkdown\n\n这是一个 Markdown 编辑器。';

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
    final Brightness brightness = Theme.of(context).brightness;
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

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("zh-CN");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
    } catch (e) {
      Logger.error('TTS 初始化失败', e);
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      Logger.error('TTS 朗读失败', e);
    }
  }

  Future<void> _translate(String text) async {
    if (text.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _translationManager.translate(text);

      if (!mounted) return;
      Navigator.pop(context);

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

        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newOffset),
        );

        setState(() {});

        imageBase64Cache.remove(imageId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片已删除')),
        );
      }
    }
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

        final bgColor =
            isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F2F5);
        final cardColor = isDark ? const Color(0xFF252526) : Colors.white;
        final dividerColor = Theme.of(context).dividerColor;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: HomeAppBar(
            fileName: fileName,
            isDark: isDark,
            cardColor: cardColor,
            dividerColor: dividerColor,
            viewMode: _viewMode,
            isFullScreen: _isFullScreen,
            onOpenFile: () => openFile(_controller, () => setState(() {})),
            onSaveFile: () => saveFile(_controller.text),
            onSaveAsFile: () => saveAsFile(_controller.text),
            onViewModeChanged: (mode) => setState(() => _viewMode = mode),
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
                        child: EditorPanel(
                          isDark: isDark,
                          cardColor: cardColor,
                          focusNode: _focusNode,
                          controller: _controller,
                          imageBase64Cache: imageBase64Cache,
                          onPaste: () =>
                              handlePaste(_controller, () => setState(() {})),
                          onInsertImage: () => insertImageFromFile(
                              _controller, () => setState(() {})),
                          onTextChanged: () => setState(() {}),
                        ),
                      ),
                    if (_viewMode == ViewMode.split)
                      DragSplitter(
                        constraints: constraints,
                        isDark: isDark,
                        onDrag: (delta) {
                          setState(() {
                            _editAreaRatio += delta;
                            _editAreaRatio = _editAreaRatio.clamp(0.1, 0.9);
                          });
                        },
                      ),
                    if (_viewMode == ViewMode.preview ||
                        _viewMode == ViewMode.split)
                      Expanded(
                        child: PreviewPanel(
                          isDark: isDark,
                          cardColor: cardColor,
                          isTocExpanded: _isTocExpanded,
                          onToggleToc: () =>
                              setState(() => _isTocExpanded = !_isTocExpanded),
                          tocController: _tocController,
                          text: _controller.text,
                          imageBase64Cache: imageBase64Cache,
                          onShowImagePreview: (imageId, altText) {
                            showDialog(
                              context: context,
                              builder: (context) => ImagePreviewDialog(
                                imageId: imageId,
                                altText: altText,
                                imageBase64Cache: imageBase64Cache,
                              ),
                            );
                          },
                          onTranslate: _translate,
                          onSpeak: _speak,
                        ),
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
