# Omarchy Switchboard

为 Omarchy 提供窗口缩略图切换与工作区预览网格，采用 **QML + TypeScript + Lua**。
需求、交互规则和技术路线见 [计划书](计划书.md)。

目前是基础项目框架：已提供类型、少量纯逻辑、QML 组件骨架、TypeScript 构建链和 Qt 测试。
窗口捕获、真实焦点切换、修饰键释放与快捷键接管将在 P0 验证后实现。
开发插件 ID 为 `jessie.switchboard`，版本为 `0.1.0`；正式发布前确认作者与命名。

## 开发环境

需要 Node.js 22.12 或更高版本（建议使用 LTS）、npm，以及与当前 Omarchy 匹配的
Qt 6、Quickshell 和 Omarchy shell 源码。Qt 工具默认从 `/usr/lib/qt6/bin/` 查找。
第三方运行库为空；Node.js 和 npm 包只用于开发及构建。

```bash
npm ci
npm run check
```

| 命令 | 用途 |
| --- | --- |
| `npm run typecheck` | 检查业务 TypeScript 和构建脚本的独立类型环境 |
| `npm run build` | 类型检查后生成 `.mjs` 并组装完整插件目录 |
| `npm run dev` | 监听源码并重新构建，输出保留在仓库中 |
| `npm run lint:qml` | 构建并检查 QML 与 Omarchy/Quickshell 导入 |
| `npm run test:qt` | 构建并在无界面的 Qt 引擎中测试发布 ESM |
| `npm run validate` | 构建并执行 Omarchy manifest 校验 |
| `npm run check` | 一次构建，依次执行 QML 检查、Qt 测试和插件校验 |

`QT_BIN_DIR` 可指定 Qt 工具目录，`OMARCHY_SHELL_DIR` 可指定 shell 源码目录。
QML 检查使用仓库 `.cache/` 下的模块路径，不改动系统源码。

## 项目结构

```text
Overlay.qml                   Omarchy overlay 入口
controllers/                  会话与真实激活协调
adapters/                     Hyprland 模型适配
components/                   窗口、工作区和预览卡片骨架
previews/                     捕获提供者骨架
src/types/                    记录、配置与会话协议类型
src/logic/                    TypeScript 纯逻辑及统一导出
scripts/                      TypeScript 构建与检查工具
i18n/                         英文、简体中文文案
tests/unit/                   Qt 中的 ESM 调用与边界测试
tests/fixtures/               无桌面依赖的测试数据
tests/integration/            实际桌面验收说明
docs/                         架构与阶段说明
generated/Logic.mjs            自动生成的开发产物
dist/plugin/                  自动组装的可分发插件目录
```

修改 `.ts` 后运行构建；`.mjs`、`dist/` 和 `node_modules/` 均由工具生成并忽略提交。
业务模块开启严格检查、索引边界检查和可选字段检查；面向 Qt 的代码不依赖 Node 或浏览器 API。

## 安装与后续接入

当前构建和检查仅作用于仓库。`dist/plugin/` 包含 manifest、QML、预编译 `.mjs`、Lua、
翻译和许可，可作为后续安装包的基础；终端用户运行时无需 TypeScript 工具链。

安装/卸载管理与快捷键接管暂未实现，`bindings.lua` 是保留现有绑定的空接入模块。
P0 通过后再实现用户目录部署、备份和受管理 include，按计划书处理 Alt+Tab、Super+Tab
以及 Super+grave 的冲突、启停与恢复。此时才能验收实际桌面切换行为。

许可为 MIT。当前代码未复制参考项目源码，后续复用时保留各自版权和许可声明。
