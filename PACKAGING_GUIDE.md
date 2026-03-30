# KKMarkdown Windows 打包指南

本项目提供了自动化构建脚本，可同时打包出“免安装绿色版压缩包”和“MSIX 格式安装包”，并统一输出到指定的成品目录中。

## 一键自动化打包 (推荐)

在项目根目录下，直接在 PowerShell 中执行构建脚本：
```powershell
.\build_package.ps1
```
*(注意：如果提示权限或执行策略拦截，请使用 `powershell -ExecutionPolicy Bypass -File .\build_package.ps1` 运行)*

脚本执行流程：
1. 清理并准备根目录下的 `release/` 文件夹。
2. 调用 `flutter build windows` 编译 Release 版本。
3. 将构建产物打包为 ZIP 格式（绿色免安装版），放入 `release/`。
4. 调用 `msix` 插件生成 Windows 标准安装包（`.msix`）。
5. 将安装包移动至 `release/` 目录。

打包完成后，您可以直接在 `release/` 目录下获取两个成品文件：
- `kkmarkdown_portable.zip` (解压即用的绿色版)
- `kkmarkdown_setup.msix` (双击即可安装的安装包)

## 手动打包步骤 (可选)

如果自动化脚本不可用，您也可以按以下步骤手动打包：

1. **清理构建缓存** (可选但推荐):
   ```powershell
   flutter clean
   flutter pub get
   ```

2. **构建 Windows Release 版本**:
   ```powershell
   flutter build windows
   ```
   *这会在 `build\windows\x64\runner\Release\` 目录下生成可执行文件 `kkmarkdown.exe` 及相关依赖。您可以手动压缩该文件夹作为绿色版。*

3. **生成 MSIX 安装包**:
   ```powershell
   dart run msix:create
   ```
   *注意: 如果遇到证书提示报错，通常安装包已生成完毕，您可以直接忽略报错。*

## MSIX 配置说明
MSIX 打包配置已在 `pubspec.yaml` 中设置：
```yaml
msix_config:
  display_name: KKMarkdown
  publisher_display_name: KK
  identity_name: kkmarkdown
  msix_version: 1.0.0.0
  logo_path: windows\runner\resources\app_icon.ico
  architecture: x64
```
如果需要修改应用名称、发布者或版本号，请直接编辑 `pubspec.yaml` 中的 `msix_config` 节点，然后再执行打包脚本。
