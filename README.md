
# KKMarkdown

一个轻量级的 Markdown 阅读器/编辑器，使用 Flutter 开发，支持 Windows 平台。

## 主要功能

- **Markdown 编辑与预览**：左侧编辑，右侧实时预览。
- **划词功能**：在预览区选中文字后，支持：
  - **翻译**：调用配置的翻译接口进行翻译。
  - **朗读**：使用 TTS 朗读选中文本。
- **自定义翻译源**：
  - 支持配置多个翻译服务商（如百度、谷歌等）。
  - 可自定义 API Key、App ID 和 Endpoint。
- **多主题支持**：跟随系统或手动切换明暗主题。

## 技术栈

- **框架**：Flutter (Windows Desktop)
- **状态管理**：Provider
- **Markdown 渲染**：flutter_markdown
- **网络请求**：http
- **本地存储**：shared_preferences
- **文本转语音**：flutter_tts
- **窗口管理**：window_manager

## 快速开始

1. **环境准备**：
   - 确保已安装 Flutter SDK (推荐 3.3.0+)。
   - 确保已安装 Visual Studio (C++ 桌面开发环境)。

2. **运行项目**：
   ```bash
   flutter pub get
   flutter run -d windows
   ```

3. **配置翻译**：
   - 启动应用后，点击右上角设置图标。
   - 填写您的翻译 API Key (例如百度翻译 API)。
   - 保存配置即可使用划词翻译功能。

## 目录结构说明

本项目主要目录和文件功能说明如下：

- **`lib/`**：核心业务代码目录（Dart 源码）
  - **`api/`**：网络请求和外部服务接口封装（例如翻译接口调用逻辑 `translation_manager.dart`）。
  - **`models/`**：数据模型和实体类定义（例如翻译配置模型 `translation_config.dart`）。
  - **`pages/`**：应用的各个 UI 页面组件（例如主视图 `home_page.dart` 和设置视图 `settings_page.dart`）。
  - **`providers/`**：状态管理类，基于 Provider 实现全局状态数据共享（例如全局应用状态 `app_provider.dart`）。
  - **`utils/`**：通用工具类和辅助函数（例如日志记录工具 `logger.dart`）。
  - **`main.dart`**：Flutter 应用的入口文件，负责初始化应用。
- **`test/`**：单元测试和 Widget 测试代码存放目录。
- **`windows/`**：Windows 桌面平台相关的原生工程文件和构建配置（C++ / CMake）。
- **`pubspec.yaml`**：Flutter 项目的配置文件，用于管理项目依赖包、版本号、以及静态资源等。
- **`analysis_options.yaml`**：Dart 代码静态分析和 Lint 规则配置文件，用于规范代码风格。
