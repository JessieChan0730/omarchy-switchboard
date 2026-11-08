# Omarchy Switchboard

为 Omarchy 提供窗口切换面板与工作区概览，采用 **QML + TypeScript + Lua**。
完整交互目标见 [计划书](计划书.md)。开发插件 ID 为 `jessie.switchboard`。

当前开发版已接入真实 Hyprland 数据、窗口候选过滤、MRU、工作区网格与排序、合法空槽位、
独立新建入口、窗口/工作区确认激活，以及两对象快速回切。面板支持 Tab/Shift+Tab、
方向键、Enter、Esc 和鼠标点击，并跟随 Omarchy 的颜色、字体、圆角和中英文设置。

窗口卡片目前显示应用图标和标题，工作区卡片显示窗口几何布局占位。
**真实截图缩略图、预览缓存和性能预算尚未实现。** 多显示器逻辑已有自动测试，
双屏实机、全屏/XWayland、左右修饰键与极快点按仍需按 [桌面验收说明](tests/integration/README.md) 测试。

## 开发

### 环境与检查

需要 Node.js 22.12 或更高版本、npm、Python 3、Lua（`luac`）、Bash，以及与当前 Omarchy
匹配的 Qt 6、Quickshell 和 Omarchy shell 源码。安装与桌面测试需要正在运行的 Hyprland Lua 会话。
Node.js 和 npm 包只用于开发及构建，插件运行时使用 QML、预编译 ESM 和 Lua。

```bash
npm ci
npm run check
```

| 命令 | 用途 |
| --- | --- |
| `npm run typecheck` | 检查业务 TypeScript 和构建脚本 |
| `npm run build` | 类型检查后生成 `.mjs` 并组装 `dist/plugin/` |
| `npm run dev` | 监听源码并重新构建；产物保留在仓库中 |
| `npm run lint:qml` | 检查 QML 与 Omarchy/Quickshell 导入 |
| `npm run test:qt` | 在 Qt 引擎中测试发布 ESM 的纯逻辑 |
| `npm run validate` | 执行 Omarchy manifest 校验 |
| `npm run check` | 构建、QML 检查、Qt 测试、manifest、Lua/Bash 语法与安装器测试 |

`QT_BIN_DIR` 可指定 Qt 工具目录，`OMARCHY_SHELL_DIR` 可指定 shell 源码目录。
QML 工具元数据的兼容处理仅写入仓库 `.cache/`，不改动系统源码。

### 本地安装与更新

在仓库根目录执行：

```bash
./scripts/install.sh
```

脚本先运行完整检查，再部署并启用 `~/.config/omarchy/plugins/jessie.switchboard/`。
**首次安装默认保留现有快捷键**，通过下面的命令打开面板测试。
重复安装会更新插件，并保留上次选择的快捷键模式和插件设置。
部署使用独立的 `runtime/<构建 ID>/` 路径，安装器核对新实例的构建 ID，避免宿主 QML 缓存继续运行旧代码。

```bash
# 窗口面板：单屏只列出当前普通工作区窗口
omarchy-shell shell summon jessie.switchboard '{"mode":"window"}'

# 工作区网格：包含合法空槽位
omarchy-shell shell summon jessie.switchboard '{"mode":"workspace"}'

# 反向初始选择
omarchy-shell shell summon jessie.switchboard '{"mode":"workspace","direction":-1}'
```

打开后使用 Tab/Shift+Tab 或方向键选择，Enter 或鼠标点击确认，Esc 取消。
命令行打开默认使用 Enter 确认，不要求按住修饰键。初次打开仍按方向移动一次选中项。

启用计划中的快捷键：

```bash
./scripts/install.sh --bindings
```

| 快捷键 | 行为 |
| --- | --- |
| `Alt+Tab` / `Alt+Shift+Tab` | 窗口正向/反向选择，松开 Alt 确认 |
| `Super+Tab` / `Super+Shift+Tab` | 工作区正向/反向选择，松开 Super 确认 |
| `Alt+grave` | 最近两个普通窗口之间回切 |
| `Super+grave` | 最近两个普通工作区之间回切 |

`grave` 是 Esc 下方的反引号键，无需额外按 Shift。启用绑定会替换原来的 Alt 窗口循环、
Super 工作区循环，以及 **Super+grave 的 Quake console 入口**；`Super+Shift+grave`
和 `Super+Ctrl+Tab` 保持原绑定。自定义键盘布局可调整仓库 `bindings.lua`，重新安装后测试。

修饰键确认目前在面板打开期间异步调用本机 `hl.is_key_down()`，同时检查左右 Alt 或左右 Super。
持续按住不会因固定超时确认；查询失败时保留面板，可用 Enter 或 Esc。
全局快捷键和面板 Tab 使用单一路径，避免同一次按键重复步进。该路径仍需真实键盘时序验收。

关闭快捷键接管并保留插件供命令测试：

```bash
./scripts/install.sh --no-bindings
```

### 卸载与恢复

```bash
./scripts/uninstall.sh
```

安装器修改配置前备份用户 `shell.json`、`hypr/bindings.lua` 和已有插件。
备份与安装记录保存在 `${XDG_STATE_HOME:-~/.local/state}/omarchy-switchboard/`。
卸载只移除本插件条目及受管理的 Lua include，保留用户后来添加的其他设置和绑定；
如果安装前存在同 ID 插件，会恢复其目录和原条目，并保留后来修改的设置字段。
重复卸载可安全执行，备份目录保留供手动查阅。

安装、更新及卸载均执行 `hyprctl reload`、`hyprctl configerrors` 和插件重新扫描。
配置检查失败或插件没有报告就绪时，安装器回滚本次修改。文件损坏或受管理标记不完整时，
脚本会报告错误，不覆盖无法解析的配置。

开启快捷键接管时，插件每两秒更新一次运行状态租约。停用或异常退出后，租约清除或在六秒内过期，
Lua 绑定退回直接切换；`Super+grave` 退回 Quake console。面板关闭后停止修饰键查询。
可用 `omarchy plugin disable jessie.switchboard` 停用插件；要立即恢复原始绑定，使用 `--no-bindings` 或卸载脚本。

### 诊断与配置

```bash
# 查看是否就绪、候选数量、选中索引、会话阶段及绑定模式，不输出标题或图像
omarchy-shell jessie.switchboard status

# 面板中的步进、确认和取消
omarchy-shell jessie.switchboard step -1
omarchy-shell jessie.switchboard confirm
omarchy-shell jessie.switchboard cancel

# 测试两对象回切
omarchy-shell jessie.switchboard previous window
omarchy-shell jessie.switchboard previous workspace

# 更新本插件设置，合并保留其他字段
omarchy-shell jessie.switchboard settings '{"showMonitorLabels":false}'
```

设置存放于用户 `shell.json` 的 `plugins[]` 中本插件对象，支持 `configVersion: 1`、
`showWorkspaceLabels`、`showMonitorLabels` 和 `slotsPerMonitor`（1–10）。编号起点来自 Omarchy
的显示器映射；缺少映射时只展示真实工作区，不猜测或创建编号段。跨显示器候选使用真实全局 ID，
界面显示显示器和本地槽位。`bindingsEnabled` 由安装脚本管理，应结合 include 一起调整。
缓存相关字段保留为后续捕获实现的配置，当前没有图像缓存。

窗口与工作区历史独立维护；预览高亮和取消不改变历史。工作区新建入口不参加 Tab 循环，
鼠标点击可创建，方向键明确选择后按 Enter 可创建；停留在新建入口时松开修饰键只关闭面板。
目标确认前会重新验证身份和显示器，覆盖层释放输入后再激活，最多进行三次焦点核对。

### 项目结构

```text
Overlay.qml                   宿主入口、面板交互与全局快捷键
controllers/                  会话、配置、真实激活协调
adapters/                     Hyprland 数据与真实历史
components/                   窗口卡片、工作区布局与主题
src/logic/                    候选、排序、状态机、校验和坐标换算
bindings.lua                  带运行状态降级的 Lua 绑定
scripts/install.sh            本地构建、检查和安装
scripts/uninstall.sh          本地卸载与恢复
scripts/local_plugin.py       部署事务、备份与配置条目管理
scripts/build.ts              TypeScript/ESM 构建
scripts/check.ts              静态检查与自动测试
tests/unit/                   Qt 中的 ESM 与纯文本测试
tests/installer/              隔离目录中的安装、回滚与卸载测试
tests/integration/            实际桌面验收步骤
dist/plugin/                  完整构建产物
```

`npm run dev` 只更新仓库产物；完成修改后再运行 `./scripts/install.sh` 部署。
业务代码不依赖 Node 或浏览器 API；运行时无需 TypeScript 工具链。

## 许可

MIT。当前代码未复制参考项目源码，后续复用时保留各自版权和许可声明。
