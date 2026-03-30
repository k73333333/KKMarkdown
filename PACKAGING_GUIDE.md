# KKMarkdown Windows 打包指南

本项目提供了自动化构建脚本，可同时打包出“免安装绿色版压缩包”和“MSIX 格式安装包”，并统一输出到指定的成品目录中。

## 一键自动化打包 (推荐)

在项目根目录下，直接在 PowerShell 中执行构建脚本：
```powershell
.\build_package.ps1
```
*(注意：如果提示权限或执行策略拦截，请使用 `powershell -ExecutionPolicy Bypass -File .\build_package.ps1` 运行)*

脚本执行流程：
1. 清理并准备根目录下的 `outputs/` 文件夹。
2. 调用 `flutter build windows` 编译 Release 版本。
3. 将构建产物打包为 ZIP 格式（绿色免安装版），放入 `outputs/`。
4. 调用 `msix` 插件生成 Windows 标准安装包（`.msix`）。
5. 将安装包移动至 `outputs/` 目录。

打包完成后，您可以直接在 `outputs/` 目录下获取三个成品文件：
- [kkmarkdown_setup.exe](./outputs/kkmarkdown_setup.exe) (推荐：标准双击安装程序，基于 Inno Setup 制作)
- [kkmarkdown_portable.zip](./outputs/kkmarkdown_portable.zip) (免安装绿色版，解压即用)
- [kkmarkdown_msix_setup.msix](./outputs/kkmarkdown_msix_setup.msix) (Windows 现代安装包，可能有证书提示)

*(注：如果您刚刚执行过打包脚本，请直接点击上述链接在文件资源管理器中查看或运行)*

### ⚠️ 关于安装包 (MSIX) 报错 0x800B010A 的说明
由于本项目的 MSIX 安装包是由 `msix` 插件使用自动生成的**自签名证书**进行签名的，Windows 默认不信任此证书，所以在双击安装时可能会拦截并提示 `0x800B010A` 错误。

**解决方法（二选一）：**
1. **(推荐) 使用免安装版**：直接解压 `kkmarkdown_portable.zip` 并运行其中的 `kkmarkdown.exe`，完全绕过安装和证书限制。
2. **信任本地自签名证书**：
   - 右键点击 `kkmarkdown_setup.msix`，选择 **“属性”**。
   - 切换到 **“数字签名”** 选项卡。
   - 选中签名列表中的发布者，点击 **“详细信息”**。
   - 在弹出的窗口中点击 **“查看证书”** -> **“安装证书”**。
   - 选择 **“本地计算机”**（需要管理员权限）。
   - 选择 **“将所有的证书都放入下列存储”**，点击 **“浏览”**，选择 **“受信任的根证书颁发机构”**。
   - 一路点击确定完成导入，然后重新双击运行 `.msix` 即可成功安装。

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
