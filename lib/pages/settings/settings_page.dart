import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/translation_config.dart';
import 'widgets/api_config_card.dart';
import 'widgets/theme_color_picker.dart';

/**
 * 设置页面
 * 用于配置翻译 API Key 等信息
 */
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late List<TranslationConfig> _editingConfigs;
  // 是否在 Markdown 预览面板的右键菜单中显示“翻译”按钮
  // 该状态同步自全局配置 (AppProvider)，在设置页中可以通过 Switch 组件进行开关切换
  bool _showTranslationButton = false;

  // 是否在 Markdown 预览面板的右键菜单中显示“▶ 播放” (文本转语音) 按钮
  // 该状态同步自全局配置 (AppProvider)，在设置页中可以通过 Switch 组件进行开关切换
  bool _showTtsButton = true;
  late Color _themeColor;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _editingConfigs =
        provider.translationConfigs.map((e) => e.copyWith()).toList();
    _showTranslationButton = provider.showTranslationButton;
    _showTtsButton = provider.showTtsButton;
    _themeColor = provider.themeColor;
  }

  /**
   * 保存配置
   */
  void _saveConfigs() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    for (var config in _editingConfigs) {
      provider.updateTranslationConfig(config);
    }
    provider.setShowTranslationButton(_showTranslationButton);
    provider.setShowTtsButton(_showTtsButton);
    provider.setThemeColor(_themeColor);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('配置已保存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('设置'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '基础设置', icon: Icon(Icons.settings)),
              Tab(text: 'API 配置', icon: Icon(Icons.api)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: '保存配置',
              onPressed: _saveConfigs,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildBasicSettings(),
            _buildApiSettings(),
          ],
        ),
      ),
    );
  }

  /**
   * 构建基础设置页面
   */
  Widget _buildBasicSettings() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: Text(
            '主题设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          title: const Text('主题颜色'),
          subtitle: const Text('选择应用的主题配色'),
          trailing: ThemeColorPicker(
            selectedColor: _themeColor,
            presetColors: AppProvider.presetColors,
            onColorSelected: (color) {
              setState(() {
                _themeColor = color;
              });
            },
          ),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            '编辑器悬浮菜单',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SwitchListTile(
          title: const Text('显示划词翻译按钮'),
          subtitle: const Text('选中文本时弹出翻译选项（需在 API 配置中填写 Key）'),
          value: _showTranslationButton,
          onChanged: (value) {
            setState(() {
              _showTranslationButton = value;
            });
          },
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('显示文本朗读按钮'),
          subtitle: const Text('选中文本时弹出 TTS 朗读选项'),
          value: _showTtsButton,
          onChanged: (value) {
            setState(() {
              _showTtsButton = value;
            });
          },
        ),
      ],
    );
  }

  /**
   * 构建 API 配置页面
   */
  Widget _buildApiSettings() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _editingConfigs.length,
      itemBuilder: (context, index) {
        return ApiConfigCard(
          config: _editingConfigs[index],
          onChanged: () {},
        );
      },
    );
  }
}
