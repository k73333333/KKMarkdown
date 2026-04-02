<!--
 * @Author: fukaidong qiji777@yeah.net
 * @Date: 2026-03-11 09:44:26
 * @LastEditors: fukaidong qiji777@yeah.net
 * @LastEditTime: 2026-04-02 19:29:40
 * @Description: .
-->

# KKMarkdown

一个轻量级的 Markdown 阅读器/编辑器，使用 Flutter 开发，支持 Windows 平台。

**作者**：fukaidong


## 成品安装包与运行

如果您只想直接运行应用，可以获取已打包好的成品文件。
我们提供了自动化构建脚本 `build_package.ps1`，构建完成后，成品将存放在项目根目录的 `outputs/` 文件夹中：

- **标准安装包 (.exe)**：`outputs/kkmarkdown_setup.exe` (最推荐，双击无痛安装，自动创建快捷方式)
- **免安装绿色版**：`outputs/kkmarkdown_portable.zip` (解压即可运行)
- **Windows 安装包**：`outputs/kkmarkdown_msix_setup.msix` (可能需要手动信任证书)

详细的打包说明请参阅 [PACKAGING_GUIDE.md](./PACKAGING_GUIDE.md)。


## 主要功能

- **Markdown 编辑与预览**：左侧编辑，右侧实时预览。
- **本地文件管理**：支持打开、编辑、保存 `.md` 和 `.txt` 文件。
- **划词功能**：在预览区选中文字后，支持：(待完善)
  - **翻译**：调用配置的翻译接口进行翻译。
  - **朗读**：使用 TTS 朗读选中文本。
- **自定义翻译源**：(待完善)
  - 支持配置多个翻译服务商（如百度、谷歌等）。
  - 可自定义 API Key、App ID 和 Endpoint。
- **多主题支持**：跟随系统或手动切换明暗主题。

## 技术栈

- **框架**：Flutter (Windows Desktop)
- **状态管理**：Provider
- **Markdown 渲染**：flutter_markdown
- **文件选择**：file_picker
- **网络请求**：http
- **本地存储**：shared_preferences
- **文本转语音**：flutter_tts
- **窗口管理**：window_manager

## 快速开始 (开发者)

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
