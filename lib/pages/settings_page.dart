
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/translation_config.dart';

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
  // 临时存储编辑中的配置，避免直接修改 Provider 中的数据
  late List<TranslationConfig> _editingConfigs;

  // 悬浮菜单开关状态
  bool _showTranslationButton = false;
  bool _showTtsButton = false;

  @override
  void initState() {
    super.initState();
    // 从 Provider 获取当前配置的副本
    final provider = Provider.of<AppProvider>(context, listen: false);
    _editingConfigs = provider.translationConfigs.map((e) => e.copyWith()).toList();
    _showTranslationButton = provider.showTranslationButton;
    _showTtsButton = provider.showTtsButton;
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
          final config = _editingConfigs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        config.provider.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: config.isEnabled,
                        onChanged: (value) {
                          setState(() {
                            config.isEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'API Key / Access Token',
                      border: OutlineInputBorder(),
                    ),
                    controller: TextEditingController(text: config.apiKey)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: config.apiKey.length),
                      ),
                    onChanged: (value) {
                      config.apiKey = value;
                    },
                    obscureText: true, // 隐藏敏感信息
                  ),
                  if (config.provider == 'baidu') ...[
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'App ID',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: config.appId)
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: config.appId?.length ?? 0),
                        ),
                      onChanged: (value) {
                        config.appId = value;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '自定义 Endpoint (可选)',
                      border: OutlineInputBorder(),
                      hintText: 'https://api.example.com/v1',
                    ),
                    controller: TextEditingController(text: config.endpoint)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: config.endpoint?.length ?? 0),
                      ),
                    onChanged: (value) {
                      config.endpoint = value;
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
  }
}
