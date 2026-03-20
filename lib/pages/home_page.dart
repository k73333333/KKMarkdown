import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/app_provider.dart';
import '../api/translation_manager.dart';
import '../utils/logger.dart';
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

class _HomePageState extends State<HomePage> {
  /** 当前的视图模式 */
  ViewMode _viewMode = ViewMode.split;

  /** Markdown 文本内容 */
  final TextEditingController _controller = TextEditingController();

  /** 文本转语音实例 */
  final FlutterTts _flutterTts = FlutterTts();

  /** 翻译服务管理器实例 */
  final TranslationManager _translationManager = TranslationManager();

  @override
  void initState() {
    super.initState();
    // 初始化 TTS
    _initTts();
    // 设置默认示例文本
    _controller.text =
        '# 欢迎使用 KKMarkdown\n\n这是一个轻量级的 Markdown 编辑器。\n\n## 功能特点\n- 实时预览\n- 划词翻译\n- 文本朗读\n\n试着选中这段文字看看！';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KKMarkdown'),
        actions: [
          // 视图切换按钮组
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ToggleButtons(
              borderRadius: BorderRadius.circular(8.0),
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
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(Icons.edit))),
                Tooltip(
                    message: '双屏预览',
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(Icons.vertical_split))),
                Tooltip(
                    message: '仅预览',
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(Icons.visibility))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // 左侧编辑区
          if (_viewMode == ViewMode.edit || _viewMode == ViewMode.split)
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                color: Theme.of(context).cardColor,
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '在此输入 Markdown 内容...',
                  ),
                  onChanged: (text) {
                    setState(() {}); // 触发预览更新
                  },
                ),
              ),
            ),
          // 分割线
          if (_viewMode == ViewMode.split) const VerticalDivider(width: 1),
          // 右侧预览区
          if (_viewMode == ViewMode.preview || _viewMode == ViewMode.split)
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SelectionArea(
                  child: Markdown(
                    data: _controller.text,
                    selectable: true,
                    onTapText: () {
                      // 点击文本事件
                    },
                  ),
                  contextMenuBuilder: (BuildContext context,
                      SelectableRegionState selectableRegionState) {
                    return AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: selectableRegionState.contextMenuAnchors,
                      buttonItems: [
                        ...selectableRegionState.contextMenuButtonItems,
                        ContextMenuButtonItem(
                          onPressed: () {
                            final text = selectableRegionState
                                .textEditingValue.selection
                                .textInside(selectableRegionState
                                    .textEditingValue.text);
                            _translate(text);
                            selectableRegionState.hideToolbar();
                          },
                          label: '翻译',
                        ),
                        ContextMenuButtonItem(
                          onPressed: () {
                            final text = selectableRegionState
                                .textEditingValue.selection
                                .textInside(selectableRegionState
                                    .textEditingValue.text);
                            _speak(text);
                            selectableRegionState.hideToolbar();
                          },
                          label: '▶ 播放',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
