<!--
 * @Author: fukaidong qiji777@yeah.net
 * @Date: 2026-03-20 14:48:06
 * @LastEditors: fukaidong qiji777@yeah.net
 * @LastEditTime: 2026-03-20 15:09:18
 * @Description: .
-->
---
name: "project-structure"
description: "说明项目各模块分别在哪里。当新增文件、重构目录或询问项目结构时必须调用此技能；若发现新增了文件，必须同步更新此技能的内容。"
---

# 项目结构与模块说明 (Project Structure)

本项目是一个基于 Flutter 的应用程序。以下是项目各主要模块的分布与职责说明：

## 核心目录结构 (`lib/`)

- **`lib/api/`**: 存放与外部接口、网络请求相关的逻辑。例如：`translation_manager.dart` 等接口服务封装。
- **`lib/models/`**: 存放数据模型和实体类。例如：`translation_config.dart` 等与业务相关的数据结构。
- **`lib/pages/`**: 存放 UI 页面组件。例如：`home_page.dart` (主页视图), `settings_page.dart` (设置视图) 等。
- **`lib/providers/`**: 存放状态管理相关的 Provider 类。例如：`app_provider.dart`，用于跨组件状态共享和管理。
- **`lib/utils/`**: 存放通用工具类和辅助函数。例如：`logger.dart` 等公共方法。
- **`lib/main.dart`**: 应用程序的入口文件，包含 App 的初始化与路由配置。

## 测试目录 (`test/`)
- 存放单元测试、Widget 测试逻辑。例如：`widget_test.dart`。

## 平台特定代码
- **`windows/`**: 包含 Windows 平台专有的构建脚本和 C++ 代码。

---

## 维护规则 (极其重要)

1. **新增文件时强制更新**：每次在项目中**新增**任何文件或模块时，**必须**同步更新本技能文件（`.trae/skills/project-structure/SKILL.md`），将新的目录或重要模块补充到上述结构说明中。
2. **职责单一原则**：确保每个文件放置在对应职责的目录下，严禁跨模块随意放置文件（例如：页面 UI 代码绝不能放在 `api/` 目录中）。
3. **中文要求**：必须始终保持本技能文件的内容及注释为中文。