import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/translation_config.dart';
import '../api/translation_manager.dart';
import '../utils/logger.dart';

/**
 * 应用全局状态管理
 * 负责管理主题、翻译配置等核心数据
 */
class AppProvider with ChangeNotifier {
  /** 当前主题模式 */
  ThemeMode _themeMode = ThemeMode.system;

  /** 当前的主题色 */
  Color _themeColor = Colors.blue;

  /** 支持的主题色预设列表 */
  static const List<Color> presetColors = [
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.brown,
  ];

  /** 翻译配置列表 */
  List<TranslationConfig> _translationConfigs = [];

  /** 当前选中的翻译服务商 */
  String _selectedProvider = 'baidu';

  /** 是否显示划词翻译按钮 */
  bool _showTranslationButton = false;

  /** 是否显示文本朗读按钮 */
  bool _showTtsButton = false;

  /** 当前打开的文件绝对路径 */
  String? _currentFilePath;

  /**
   * 获取当前主题模式
   */
  ThemeMode get themeMode => _themeMode;

  /**
   * 获取当前主题颜色
   */
  Color get themeColor => _themeColor;

  /**
   * 获取翻译配置列表
   */
  List<TranslationConfig> get translationConfigs => _translationConfigs;

  /**
   * 获取当前选中的翻译服务商
   */
  String get selectedProvider => _selectedProvider;

  /**
   * 是否显示划词翻译按钮
   */
  bool get showTranslationButton => _showTranslationButton;

  /**
   * 是否显示文本朗读按钮
   */
  bool get showTtsButton => _showTtsButton;

  /**
   * 获取当前打开的文件绝对路径
   */
  String? get currentFilePath => _currentFilePath;

  /**
   * 初始化 Provider
   * 加载本地存储的配置
   */
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载主题配置
      final themeIndex = prefs.getInt('themeMode') ?? 0;
      _themeMode = ThemeMode.values[themeIndex];

      // 加载主题色
      final colorValue = prefs.getInt('themeColor');
      if (colorValue != null) {
        _themeColor = Color(colorValue);
      }

      // 加载翻译配置
      final configJson = prefs.getString('translationConfigs');
      if (configJson != null) {
        try {
          final List<dynamic> jsonList = jsonDecode(configJson);
          _translationConfigs =
              jsonList.map((e) => TranslationConfig.fromJson(e)).toList();
        } catch (e) {
          Logger.error('解析翻译配置失败', e);
        }
      }

      // 如果配置为空，添加默认配置
      if (_translationConfigs.isEmpty) {
        _translationConfigs = [
          TranslationConfig(
            provider: 'baidu',
            apiKey: '',
            appId: '',
            isEnabled: true,
          ),
          TranslationConfig(
            provider: 'google',
            apiKey: '',
            isEnabled: true,
          ),
        ];
      }

      // 加载选中的服务商
      _selectedProvider = prefs.getString('selectedProvider') ?? 'baidu';

      // 加载按钮显示状态
      _showTranslationButton = prefs.getBool('showTranslationButton') ?? false;
      _showTtsButton = prefs.getBool('showTtsButton') ?? false;

      // 同步配置到 TranslationManager
      _syncToTranslationManager();

      notifyListeners();
      Logger.info('AppProvider 初始化完成');
    } catch (e, stackTrace) {
      Logger.error('AppProvider 初始化失败', e, stackTrace);
    }
  }

  /**
   * 同步配置到 TranslationManager
   */
  void _syncToTranslationManager() {
    TranslationManager().updateConfigs(_translationConfigs);
    TranslationManager().setProvider(_selectedProvider);
  }

  /**
   * 保存翻译配置到本地
   */
  Future<void> _saveTranslationConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _translationConfigs.map((e) => e.toJson()).toList();
      await prefs.setString('translationConfigs', jsonEncode(jsonList));
      await prefs.setString('selectedProvider', _selectedProvider);
    } catch (e) {
      Logger.error('保存翻译配置失败', e);
    }
  }

  /**
   * 切换主题模式
   * @param mode 新的主题模式
   */
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('themeMode', mode.index);
    } catch (e) {
      Logger.error('保存主题配置失败', e);
    }
  }

  /**
   * 切换主题色
   * @param color 新的主题色
   */
  Future<void> setThemeColor(Color color) async {
    _themeColor = color;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('themeColor', color.value);
    } catch (e) {
      Logger.error('保存主题色配置失败', e);
    }
  }

  /**
   * 更新翻译配置
   * @param config 新的翻译配置
   */
  void updateTranslationConfig(TranslationConfig config) {
    final index =
        _translationConfigs.indexWhere((c) => c.provider == config.provider);
    if (index != -1) {
      _translationConfigs[index] = config;
    } else {
      _translationConfigs.add(config);
    }

    _syncToTranslationManager();
    notifyListeners();
    _saveTranslationConfigs();
  }

  /**
   * 设置当前翻译服务商
   * @param provider 服务商标识
   */
  void setSelectedProvider(String provider) {
    _selectedProvider = provider;
    _syncToTranslationManager();
    notifyListeners();
    _saveTranslationConfigs();
  }

  /**
   * 设置是否显示划词翻译按钮
   */
  Future<void> setShowTranslationButton(bool show) async {
    _showTranslationButton = show;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('showTranslationButton', show);
    } catch (e) {
      Logger.error('保存翻译按钮状态失败', e);
    }
  }

  /**
   * 设置是否显示文本朗读按钮
   */
  Future<void> setShowTtsButton(bool show) async {
    _showTtsButton = show;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('showTtsButton', show);
    } catch (e) {
      Logger.error('保存朗读按钮状态失败', e);
    }
  }

  /**
   * 设置当前打开的文件路径
   * @param path 文件绝对路径
   */
  void setCurrentFilePath(String? path) {
    _currentFilePath = path;
    notifyListeners();
  }

  /**
   * 清除当前文件路径（用于新建文件）
   */
  void clearCurrentFile() {
    _currentFilePath = null;
    notifyListeners();
  }
}
