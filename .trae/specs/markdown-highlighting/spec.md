# Markdown 编辑器语法高亮与格式化功能规格书

## 1. 背景与目标
当前 KKMarkdown 的左侧编辑区使用了一个基础的 `TextField`，文本只呈现单一颜色，不具备语法高亮和 Markdown 实时格式化显示（如加粗、标题大小变化、代码块变色等）。
为了提升写作体验，需要引入 Markdown 语法高亮机制，使用户在编写时能够直观地看到文档结构和代码块区分。

## 2. 社区第三方组件库调研评估

在 Flutter 生态中，实现 Markdown 编辑器高亮（WYSIWYG 或语法高亮）通常有以下几种方案和对应的第三方库：

### 2.1 `qaid_markdown_editor` / `flutter_smooth_markdown`
- **特点**：这是一些自带 UI 的开箱即用型 Markdown 编辑器组件，内置了高亮、工具栏等。
- **缺点**：侵入性极强。KKMarkdown 已经深度定制了 `MarkdownTextEditingController`（用于彻底解决长 Base64 图片导致的内存和排版崩溃问题），直接替换为成品的 Editor 组件会导致之前的剪贴板图片、右键弹窗、拖拽分栏等定制逻辑全部失效。

### 2.2 `highlight` + `flutter_highlight` (基于 highlight.js)
- **特点**：纯文本的语法高亮库。可以将文本解析成不同的节点树，并在 Flutter 中渲染为不同颜色的 TextSpan。
- **适用场景**：常用于代码块的高亮展示。
- **缺点**：它更偏向于“代码高亮”，对 Markdown 本身的语法（如 `# 标题`，`**加粗**`）的支持不够富文本化（比如无法让标题字号变大）。

### 2.3 `markdown_widget` / `flutter_markdown` (当前项目中右侧预览区使用的方案)
- **特点**：将 Markdown 文本解析为 Flutter Widget 树进行渲染。
- **适用场景**：只读预览。不能直接用作输入框（TextField）的内容渲染引擎。

### 2.4 纯正则正则匹配 + 自定义 `TextSpan` (推荐方案)
鉴于本项目已经实现了一个非常强大的 `MarkdownTextEditingController`，并且在其中拦截并处理了图片短链接（`img_xxx`）和 `WidgetSpan` 交互。**最稳妥、最高效**的做法是在现有的 `buildTextSpan` 方法中，加入基于正则表达式的 Markdown 语法高亮逻辑。

## 3. 推荐实现方案：扩展现有的 `MarkdownTextEditingController`

不需要引入臃肿的第三方所见即所得库，只需在 `MarkdownTextEditingController` 中引入轻量级的语法解析逻辑：

### 3.1 核心逻辑
1. 继续重写 `buildTextSpan`。
2. 引入基础的正则表达式词法分析器，识别以下 Markdown 元素：
   - **标题 (H1-H6)**：如 `# Title`，将这些行的字体加粗并赋予特定颜色。
   - **加粗/斜体**：如 `**text**` 或 `*text*`，应用对应的 TextStyle。
   - **代码块 / 行内代码**：如 ` ``` ` 或 ` `code` `，赋予灰色背景或特殊颜色。
   - **引用**：如 `> text`，修改文字颜色。
3. 保证原有的 Base64 图片折叠渲染（WidgetSpan）优先级最高，不被破坏。

### 3.2 为什么选择此方案
- **零依赖入侵**：不破坏现有的快捷键、双屏拖拽、Base64 分离缓存机制。
- **极高的新能**：仅利用正则配合 `TextSpan` 在单帧内完成解析，避免了复杂 AST 树的构建开销。
- **UI 统一**：颜色和字体样式完全受控于当前 App 的明暗主题。

## 4. 后续任务拆解
若确定采用此方案，可拆解为以下任务：
1. 编写 Markdown 正则高亮解析类（`MarkdownHighlighter`）。
2. 将现有的 `MarkdownTextEditingController` 的 `buildTextSpan` 方法拆分为两步：
   - 第一步：剥离出所有的图片标签并替换为占位符。
   - 第二步：将剩余的纯文本交给 `MarkdownHighlighter` 进行分段染色（生成 `TextSpan` 树）。
   - 第三步：将图片占位符还原为可点击的 `WidgetSpan`。
3. 提供一组默认的高亮配色方案（适配亮色和暗色主题）。