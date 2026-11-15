# Omarchy Switchboard

**简体中文** | [English](README.en.md)

## 插件简介

Omarchy Switchboard 是 [Omarchy](https://github.com/omacom/omarchy) 的应用、窗口与工作区切换插件，运行在现有的 `omarchy-shell` 中。它提供应用图标列表、同应用窗口预览和工作区概览，方便在多个任务之间快速切换。

- **切换应用**：`Alt+Tab` 按最近使用顺序列出当前工作区的应用。同一应用合并为一个图标，多个窗口时显示数量角标；确认后进入该应用最近使用的窗口。
- **切换同应用窗口**：`Alt+反引号` 展开当前应用的窗口气泡，通过实时预览选择目标窗口；也可在应用列表中操作高亮应用。
- **切换工作区**：`Win+Tab` 显示打开时聚焦屏幕的工作区网格，包含前 5 个编号槽位及实际位于该屏幕上的其他数字工作区。空槽位显示壁纸，确认时才创建；移屏或断屏合并后的来访工作区也会保留。
- **融入桌面**：跟随 Omarchy 的颜色、字体、圆角与中英文设置。实时预览只捕获可见卡片，关闭面板后停止窗口捕获。

工作区角标沿用 Omarchy 的本屏 `1–9、0` 编号，`0` 表示第 10 个槽位；本屏编号段之外的来访工作区显示 `↳ 全局 ID`，避免重复角标。网格随数量调整，超过 12 项后固定四列并滚动查看。

### 界面预览

**Win+Tab：工作区概览，包含实时窗口预览与空槽位壁纸。**

![Win+Tab 工作区概览](docs/images/workspace-overview.png)

当前为开发版，普通命名工作区（如 `a`、`coding`）暂不纳入概览，见[已知问题](docs/known-issues.md)。窗口图像 LRU 缓存和完整 GPU / 内存性能预算尚未实现；桌面兼容性与实际验证范围见[桌面验收说明](tests/integration/README.md)及[验证记录](docs/development-validation.md)。

## 快捷键简介

以下快捷键需通过 `./scripts/install.sh --bindings` 启用。`Win` 对应 Hyprland 的 `Super`，反引号指键盘上的 `` ` / ~ `` 键。

| 快捷键 | 功能 |
| --- | --- |
| `Win+Tab` | 正向选择当前屏幕的工作区，松开 Win 确认 |
| `Win+Shift+Tab` | 反向选择当前屏幕的工作区，松开 Win 确认 |
| `Alt+Tab` | 正向选择当前工作区的应用，松开 Alt 确认 |
| `Alt+Shift+Tab` | 反向选择当前工作区的应用，松开 Alt 确认 |
| `Alt+反引号` | 正向选择同应用窗口，松开 Alt 确认 |
| `Alt+Shift+反引号` | 反向选择同应用窗口，松开 Alt 确认 |

面板打开后也可使用以下操作：

| 按键 / 操作 | 功能 |
| --- | --- |
| `Tab` / `Shift+Tab` | 按候选顺序循环选择；窗口气泡打开时，先收起气泡再切换应用 |
| 方向键 | 按行列选择，支持同时按住 Win / Alt；网格左右不跨行，上下保持同列，边缘保持原选择 |
| `Enter` / 鼠标点击 | 确认选择 |
| `Esc` | 取消选择，恢复打开前的窗口焦点 |
| 鼠标滚轮 | 内容超出面板时滚动查看 |

`Alt+Tab` 的图标面板延迟约 100 ms 显示，快速点按仍会立即处理选择与确认。当前工作区没有可切换应用时，应用列表和窗口气泡均不打开。命令行打开使用显式确认，无需按住修饰键。

启用绑定会接管上表中的六个组合。`Win+反引号`、`Win+Shift+反引号` 保留 Quake console 入口，`Win+Ctrl+Tab` 保留原有绑定。反引号按物理键码绑定，并兼容 US 国际布局的死键；自定义布局可修改仓库的 `bindings.lua` 后重新安装。

## 安装

### 环境要求

使用源码安装，需要：

- 正在运行的 Omarchy / Hyprland Lua 会话，以及匹配的 Quickshell、Qt 6 和 Omarchy shell 源码。
- Git、Node.js **22.12 或更高版本**、npm、Python 3、Lua（`lua`、`luac`）和 Bash。
- Qt 工具 `qmllint`、`qmltestrunner`，以及 `omarchy`、`omarchy-shell`、`hyprctl` 命令。
- ImageMagick，用于生成壁纸缩略图，Omarchy 默认安装。

Node.js 与 npm 仅用于构建和检查，插件运行时使用 QML、预编译 JavaScript ESM 和 Lua。壁纸缓存由 Python 3 与 ImageMagick 在独立进程中生成。

### 从源码安装

```bash
git clone https://github.com/JessieChan0730/omarchy-switchboard.git
cd omarchy-switchboard
npm ci
./scripts/install.sh
```

脚本运行完整检查后，将插件部署并启用到 `~/.config/omarchy/plugins/jessie.switchboard/`。首次安装默认保留现有快捷键；需要使用上表快捷键时执行：

```bash
./scripts/install.sh --bindings
```

安装器会备份配置和已有同 ID 插件，重新加载 Hyprland 与插件，并核对运行实例的 `buildId` 和就绪状态；部署失败时回滚本次修改。

### 检查与试用

```bash
# 查看就绪状态、构建 ID 与快捷键模式
omarchy-shell jessie.switchboard status

# 应用列表
omarchy-shell shell summon jessie.switchboard '{"mode":"window"}'

# 当前应用的窗口预览
omarchy-shell shell summon jessie.switchboard '{"mode":"app-windows"}'

# 当前屏幕的工作区概览
omarchy-shell shell summon jessie.switchboard '{"mode":"workspace"}'
```

命令打开后，使用 Tab / 方向键选择、Enter 确认、Esc 取消。加入 `"direction":-1` 可反向初始选择，例如 `'{"mode":"workspace","direction":-1}'`；打开时会按指定方向移动一次选中项。

## 更新

在已有仓库目录中执行：

```bash
git pull --ff-only
npm ci
./scripts/install.sh
```

重复安装会更新插件，并保留上次的快捷键模式和插件设置。每次部署使用独立的 `runtime/<buildId>/` 路径，核对新实例后才报告成功。

需要主动切换快捷键模式时，使用 `./scripts/install.sh --bindings` 启用，或使用以下命令恢复原始绑定并保留插件供命令调用：

```bash
./scripts/install.sh --no-bindings
```

## 卸载

在仓库根目录执行：

```bash
./scripts/uninstall.sh
```

卸载会移除本插件条目及受管理的 Lua include，保留其他插件、设置和后来添加的快捷键。如果安装前存在同 ID 插件，会恢复其目录和原条目，并保留后来修改的设置字段。重复卸载可安全执行。

备份与安装记录保存在 `${XDG_STATE_HOME:-~/.local/state}/omarchy-switchboard/`，卸载后保留，便于手动查阅。

如只需临时停用，可执行 `omarchy plugin disable jessie.switchboard`。启用绑定时，插件不可用后 Tab 组合会在运行状态租约清除或过期后退回直接循环切换；立即恢复原始绑定请使用 `--no-bindings` 或卸载脚本。

## 开发

### 开发流程

技术栈为 **QML + TypeScript + Lua**：QML 负责界面和输入，TypeScript 负责候选、排序与会话逻辑，Lua 负责全局快捷键。TypeScript 编译为 Qt 可加载的 `.mjs`，业务代码不依赖 Node.js 或浏览器 API。

在满足安装环境要求后：

```bash
npm ci
npm run dev
```

`npm run dev` 监听源码并更新仓库中的 `dist/plugin/`，不会自动部署。完成修改后执行 `./scripts/install.sh`，由脚本检查并部署到当前桌面；已有安装保留当前快捷键模式。

| 命令 | 用途 |
| --- | --- |
| `npm run typecheck` | 检查业务 TypeScript 和构建脚本 |
| `npm run build` | 类型检查后生成 ESM 并组装 `dist/plugin/` |
| `npm run dev` | 监听源码并重新构建 |
| `npm run lint:qml` | 检查 QML 与 Omarchy / Quickshell 导入 |
| `npm run test:qt` | 在 Qt 中测试发布 ESM 和真实组件布局 |
| `npm run validate` | 校验 Omarchy manifest |
| `npm run check` | 完整构建、QML / Qt / manifest 检查、Lua / Bash 语法及安装器与壁纸缓存测试 |

`QT_BIN_DIR` 可指定 Qt 工具目录，`OMARCHY_SHELL_DIR` 可指定 Omarchy shell 源码目录。QML 工具元数据的兼容处理写入仓库 `.cache/`。

## 鸣谢

感谢以下项目提供基础能力与设计参考：

- [Omarchy](https://github.com/omacom/omarchy)：插件宿主、主题、翻译与工作区栏。
- [Hyprland](https://github.com/hyprwm/Hyprland)：窗口、工作区、显示器管理与 Lua / IPC 接口。
- [Quickshell](https://quickshell.org/) 与 [Qt](https://www.qt.io/)：QML 界面、Wayland 集成与实时窗口捕获。
- [Orbit](https://github.com/rohan-patnaik/orbit)：Omarchy 原生切换面板、MRU 与输入交互的参考。
- [Hyprspace](https://github.com/KZDKM/Hyprspace)：工作区概览与窗口布局预览的设计参考。
- [Hyprshell](https://github.com/H3rmt/hyprshell)：应用图标匹配、窗口切换与配置交互的参考。

## License

本项目采用 [MIT License](LICENSE)，版权归 © 2026 Jessie 所有。
