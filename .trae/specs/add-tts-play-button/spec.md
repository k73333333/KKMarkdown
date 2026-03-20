# 预览区选中阅读与播放功能及配置检查 Spec

## Why
1. 用户希望在 Markdown 预览区选中一段文字后，可以通过一个明确的“播放”按钮直接朗读（TTS）选中的内容，使得操作更加直观。
2. 现有的翻译或朗读功能在缺乏必要配置（例如 API Key 未填写或引擎未初始化）时体验不佳，需要增加配置前置校验机制。未配置时应友好地引导用户前往设置页面。

## What Changes
- 优化 `lib/pages/home_page.dart` 中预览区的 `SelectionArea` 上下文菜单，将普通的“朗读”菜单项修改为带有播放指示的“▶ 播放”按钮。
- 增加配置校验逻辑：在用户点击“播放”或“翻译”时，如果系统检测到当前没有可用配置（如翻译的 API 密钥未填等），则中止操作并弹出一个提示对话框。
- 对话框包含两个操作：【取消】（关闭弹窗）和【前往配置】（点击后导航至 `SettingsPage`）。

## Impact
- Affected specs: 预览区划词交互、异常提示交互
- Affected code: `lib/pages/home_page.dart`

## ADDED Requirements
### Requirement 1: 选中文字播放功能
系统应当在用户选中预览区文本时，在弹出的上下文菜单中提供一个播放按钮。

#### Scenario: Success case
- **WHEN** 用户在右侧 Markdown 预览区选中文字
- **THEN** 弹出文本选择工具栏，其中包含“▶ 播放”按钮
- **WHEN** 用户点击“▶ 播放”按钮且配置正常
- **THEN** 应用调用 TTS 朗读文字，并关闭工具栏

### Requirement 2: 缺失配置时的拦截与引导
在执行翻译或播放前，系统需校验配置完整性。

#### Scenario: Missing Configuration
- **WHEN** 用户点击划词菜单中的“翻译”或“▶ 播放”
- **AND** 对应的服务尚未在设置中完成配置（如翻译未配置 API Key）
- **THEN** 系统拦截执行，弹出一个提示对话框，显示“当前服务未配置，是否前往配置？”
- **WHEN** 用户点击【前往配置】
- **THEN** 关闭对话框，并跳转到应用设置页面 (`SettingsPage`)
- **WHEN** 用户点击【取消】
- **THEN** 仅关闭对话框，不执行其他操作