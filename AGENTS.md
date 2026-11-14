# 项目代理指引

本项目是 Omarchy 的工作区与窗口切换插件。修改代码后按改动范围执行检查；完整检查为
`npm run check`，本地部署为 `./scripts/install.sh`。部署脚本会执行检查，并核对运行实例的
构建 ID。已有快捷键模式应保留，不为测试随意切换 `--bindings` / `--no-bindings`。

下列流程用于只有一块实体屏幕时，验证真实多显示器的工作区行为。其他桌面验收项目见
[tests/integration/README.md](tests/integration/README.md)。

## 单屏测试多屏：使用 Hyprland 虚拟输出

使用当前 Hyprland 会话的原生 `headless` 输出。它会产生真实显示器、焦点、工作区迁移和
输出增减事件，Omarchy 会为它分配自己的十槽编号段。虚拟屏幕不直接显示在实体屏幕上，
可用 `grim` 捕获画面，不需要安装 VNC 或虚拟显示驱动。

这是会临时切换焦点、创建测试窗口和迁移测试工作区的桌面测试。开始前说明测试范围，
记录原状态；执行期间定期报告结果；正常结束、断言失败或被中断后都要执行清理。
只迁移测试创建的工作区，不搬动用户原有工作区来凑测试数据。

### 1. 确认环境，建立本次测试目录

在项目根目录执行。需要运行中的 Omarchy / Hyprland Lua 会话，以及 `hyprctl`、
`quickshell`、`grim`、Python 3；本次使用 `foot` 创建测试窗口。

```bash
hyprctl version
hyprctl output --help
hyprctl -j monitors
omarchy-shell jessie.switchboard status

TEST_PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TEST_RUN_ID="$(date +%Y%m%d-%H%M%S)"
TEST_CACHE="$TEST_PROJECT_ROOT/.cache/virtual-monitor-tests/$TEST_RUN_ID"
TEST_RESULTS="$TEST_PROJECT_ROOT/test-results/virtual-monitors-$TEST_RUN_ID"
TEST_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
mkdir -p "$TEST_CACHE" "$TEST_RESULTS"

hyprctl -j monitors > "$TEST_CACHE/before-monitors.json"
hyprctl -j workspaces > "$TEST_CACHE/before-workspaces.json"
hyprctl -j clients > "$TEST_CACHE/before-clients.json"
hyprctl -j activewindow > "$TEST_CACHE/before-activewindow.json"
hyprctl cursorpos > "$TEST_CACHE/before-cursorpos.txt"
omarchy-shell jessie.switchboard status > "$TEST_CACHE/before-plugin.json"

for name in monitor-workspaces monitor-workspaces-merged; do
  if [[ -e "$TEST_STATE_HOME/omarchy/$name" ]]; then
    cp "$TEST_STATE_HOME/omarchy/$name" "$TEST_CACHE/$name.before"
  else
    touch "$TEST_CACHE/$name.absent"
  fi
done
```

另外记录 `git status --short`，保留用户已有改动。原窗口标题等完整桌面快照只存放于
`.cache/`；对外结果优先记录工作区 ID、显示器、数量、选择和断言，避免复制无关窗口内容。

截图和人工查看资料统一保存在 `test-results/virtual-monitors-<日期时间>/`，使用新的时间戳，
不覆盖上次截图。临时控制器、日志、进程清单和恢复备份统一存放于上述 `.cache/` 目录。
测试资料不默认加入 Git；用户确认后可以删除对应的结果目录。

### 2. 创建、配置虚拟屏幕

```bash
hyprctl output create headless
hyprctl -j monitors
cat "$TEST_STATE_HOME/omarchy/monitor-workspaces"
```

比较创建前后的输出列表，确认新增屏幕的实际名字。以下命令以新增 `HEADLESS-1`、
实体屏幕逻辑宽度为 1600 为例；不能把已有同名屏幕当成此次创建的输出。

```bash
hyprctl eval 'hl.monitor({output="HEADLESS-1",mode="1920x1080@60",position="1600x0",scale=1.2})'
hyprctl -j monitors
hyprctl configerrors
```

本机实体屏幕为 `eDP-2`，2560×1440、缩放 1.6，逻辑尺寸 1600×900；上面的虚拟屏幕
逻辑尺寸也为 1600×900。其他机器按实际尺寸配置。Omarchy 的自动布局可能重排实体屏幕
位置，配置后必须再次检查坐标；必要时按测试前快照用临时 `hl.monitor({...})` 恢复其位置。

只通过运行时 Lua 配置测试输出，不向用户配置文件写入永久虚拟屏幕规则，不修改
`/usr/share/omarchy/`。等待 Omarchy 的显示器映射和 shell 输出模型更新后再开始断言。
编号段来自 `monitor-workspaces`，不能假设第二块屏幕一定是 11–20；它可能使用其他编号段。

### 3. 创建可识别、可清理的测试窗口

先聚焦目标屏幕，再聚焦或创建其工作区。以下以虚拟屏幕 ID 11 为例：

```bash
hyprctl eval 'hl.dispatch(hl.dsp.focus({monitor="HEADLESS-1"}))'
hyprctl eval 'hl.dispatch(hl.dsp.focus({workspace="11"}))'
```

可用 `foot -c /dev/null -a switchboard-test-ws-11 -T "Switchboard test - global workspace 11"`
启动临时窗口，运行一个打印标记并持续等待的 Python 子进程。窗口内容写明：
`SWITCHBOARD TEST`、创建时全局 ID、本地角标和创建时显示器。
为每个窗口使用唯一 app ID，并记录 PID、进程组、地址和原始工作区 ID。
等待 `hyprctl -j clients` 确认窗口已经映射且归属正确后再继续。

工作区中放置测试窗口可以防止后台空工作区自行消失。填满十槽时，必须验证十个实际
工作区均存在；面板补出的前五个空槽位不能作为“十槽已满”的依据。选择额外 ID 前检查
是否已被用户占用，不能直接使用别人的 21、30 等工作区。

窗口标记是创建时的固定文字。重新编号或迁移后，以 `hyprctl -j workspaces` 为实际归属
依据，在结果说明中解释标记与新编号的差别，不把旧文字当成当前 ID。

### 4. 打开已安装插件，测试选择与确认

```bash
omarchy-shell shell summon jessie.switchboard '{"mode":"workspace","direction":1}'
omarchy-shell jessie.switchboard status
omarchy-shell jessie.switchboard step -1
omarchy-shell jessie.switchboard confirm
omarchy-shell jessie.switchboard cancel
```

命令打开默认用显式确认，不要求按住 Win。正、反向全局入口可分别通过下面的命令测试：

```bash
hyprctl eval 'hl.dispatch(hl.dsp.global("jessie.switchboard:workspace-forward"))'
hyprctl eval 'hl.dispatch(hl.dsp.global("jessie.switchboard:workspace-backward"))'
```

全局入口会检查真实修饰键状态；没有按住 Win 时可能立即确认，不能依靠此入口把面板
长时间保持打开来截图。测试期间不要混用多条输入路径重复触发同一操作。

确认前后均用 `hyprctl -j monitors` / `hyprctl -j workspaces` 核对实际活动工作区、
聚焦屏幕与目标归属；打开、步进和取消不得创建工作区。确认合法空槽位才允许创建。

`status` 只提供数量、选中索引和来源屏幕，不包含完整候选 ID 或滚动位置。需要逐项断言时，
在 `.cache/` 创建独立 Quickshell 测试控制器：

- 从已安装 `manifest.json` 的 `entryPoints.overlay` 找到实际 `runtime/<buildId>/Overlay.qml`，
  将该运行目录完整复制到测试目录的 `plugin/`，保持代码未修改；不能假设安装目录根部有
  `Overlay.qml`。
- 在测试目录创建指向 `/usr/share/omarchy/shell/Commons`、`Ui` 的链接，作为 QML 导入根。
- 控制器加载真实 `Plugin.Overlay`，使用独立插件 ID，保持绑定禁用，不抢占已安装实例的
  全局快捷键或运行租约。通过独立 IPC 提供打开、选择 ID、确认、取消和读取状态的函数。
- 读取真实候选 ID、所属显示器、选中 ID、`WorkspaceSwitcher` / `GridView.contentY`、
  表面目标屏幕和预览来源；数据必须来自实际 `HyprlandAdapter`，不注入假桌面快照。
- 用 `quickshell -p "$TEST_CACHE/shell.qml"` 启动，通过
  `quickshell ipc -p "$TEST_CACHE/shell.qml" call probe <方法> [参数]` 控制，结束时退出实例。

测试报告必须注明哪些检查来自已安装的 Omarchy shell 原实例，哪些来自相同构建的独立
测试实例，不能把后者全部写成原实例验收。

### 5. 必测场景与关键命令

以下 ID 和方向仅为示例，实际选择未占用的测试 ID 和目标显示器。

| 场景 | 操作与验收 |
| --- | --- |
| 双屏范围 | 两屏都有工作区，分别聚焦并打开面板；只列出打开时屏幕的候选，确认后另一屏幕活动工作区保持。 |
| 九宫格 | 同一屏幕创建九项并逐项选择，包含第三排；1600×900 下 `contentY` 始终为 0，全部可见时滚动交互关闭。 |
| 第十槽位 | 创建该屏幕第十个工作区，角标显示 `0`，与 Omarchy 顶部栏一致。 |
| 十槽加来访 | 目标十槽已满，用 Omarchy 的工作区移屏动作迁入两个测试工作区；全局 ID 保留，面板包含超过十项。 |
| 重复角标 | 例如 ID 11/21 均显示 `1`、20/30 均显示 `0`；分别确认，核对实际全局 ID，不能按角标去重。 |
| 动态加入与离开 | 保持面板打开，迁入新项应追加，迁出未选中项应移除，已有项顺序与选中全局 ID 保持。 |
| 来源锁定 | 面板打开后聚焦另一屏幕，候选、表面目标和预览仍使用打开时的屏幕。 |
| 选中目标移走 | 迁出选中项，面板自动取消，不跨屏激活，也不误确认其他项。 |
| 重新编号 | 选中来访工作区后改 ID，面板取消；重开后包含新 ID、更新角标、正确激活，不重建旧 ID。 |
| 目标消失 | 关闭选中来访工作区的最后一个测试窗口，等待其消失，面板取消，不重新创建旧 ID。 |
| 输出移除与合并 | 虚拟屏幕面板打开时移除该输出，面板取消；实体屏幕十槽已满时，合并后的溢出工作区作为来访保留并可激活。 |

迁移和重新编号命令：

```bash
# 聚焦测试工作区后，使用 Omarchy 自身的移屏动作；目标在右边时为 r。
hyprctl dispatch 'o.workspaces.move_to_monitor("r")'

# 面板打开期间，直接迁移指定测试工作区以观察同步。
hyprctl eval 'hl.dispatch(hl.dsp.workspace.move({workspace="31",monitor="HEADLESS-1"}))'
hyprctl eval 'hl.dispatch(hl.dsp.workspace.move({workspace="21",monitor="eDP-2"}))'

# 新 ID 必须空闲。
hyprctl eval 'hl.dispatch(hl.dsp.workspace.change_id({workspace="31",id=32}))'

# 仅移除本次创建的输出，触发实际输出移除与 Omarchy 合并。
hyprctl output remove HEADLESS-1
```

桌面更新和确认是异步的。使用有超时的短间隔轮询等待预期状态，不只依赖固定睡眠，
不在断言前连续发送未核验的操作。发现失败时保留当前状态和日志，清理后如实报告。

### 6. 截图与结果落盘

等待面板首次画面和预览内容就绪，再直接捕获目标输出。`-s 1` 按逻辑尺寸保存，便于比较。

```bash
grim -o HEADLESS-1 -s 1 "$TEST_RESULTS/01-virtual-screen-scope.png"
grim -o HEADLESS-1 -s 1 "$TEST_RESULTS/02-nine-workspaces-third-row.png"
grim -o HEADLESS-1 -s 1 "$TEST_RESULTS/03-tenth-slot-zero.png"
grim -o HEADLESS-1 -s 1 "$TEST_RESULTS/04-workspaces-with-guests.png"
grim -o eDP-2 -s 1 "$TEST_RESULTS/05-after-output-removal.png"
```

文件名按操作顺序编号并说明场景；这些示例需分别在相应测试状态执行。截图保存后查看
图片，确认捕获的是目标输出、面板已显示且能看到要验证的内容。截图作为原始证据保存，
不使用图像生成或编辑改变画面。

在同一结果目录写入：

- `README.md`：环境、构建 ID、测试方式、截图链接与场景、通过/失败/未验收项目。
- `results.json`：每项实际断言、候选全局 ID 与屏幕、选中 ID、滚动位置、实际确认结果。
- `restoration.json`：清理后的显示器、原工作区与窗口归属、焦点、状态文件和插件状态。

截图只说明画面，迁移、选择和确认正确性要同时有桌面 IPC 断言。不能只凭候选数量宣布
多屏隔离通过。最终回复链接结果说明和关键截图，注明结果目录可在用户确认后删除。

### 7. 清理与恢复验收

1. 取消原实例和独立实例的面板；若未执行输出移除场景，移除本次创建的虚拟输出。
2. 只关闭进程清单中仍匹配测试 app ID、PID / 地址的窗口与子进程；不能用 `pkill foot`
   等方式关闭用户终端。确认无测试窗口或测试子进程残留。
3. 恢复原屏幕、原活动工作区和原窗口焦点，核对分辨率、坐标、缩放、旋转。
4. 清理 Omarchy 的 `monitor-workspaces` 和 `monitor-workspaces-merged` 中本次测试显示器
   身份及合并记录。只移除本次新增记录，保留测试期间用户新增的其他记录；不存在并发
   修改时应与测试前备份逐字节一致。测试前不存在的文件也要按原状态处理。
5. 退出独立 Quickshell 实例，执行 `hyprctl reload` 和 `hyprctl configerrors`，确认内存中的
   显示器编号映射也从清理后的状态重建。重载后再次核对显示器布局与工作区。
6. 核对用户原有窗口仍处于原工作区和屏幕、原工作区集合恢复、插件 buildId 对应本次
   测试版本、`ready` 为真且原快捷键模式保持。保留用户测试期间主动进行的其他修改，
   不为追求快照完全一致而撤销这些变化。

```bash
hyprctl reload
hyprctl configerrors
hyprctl -j monitors
hyprctl -j workspaces
hyprctl -j clients
hyprctl -j activewindow
omarchy-shell jessie.switchboard status
git status --short
```

截图和结果保留给用户查看；清理完成后才报告测试结束。若恢复有未完成项，必须明确列出。

## 验证边界

本方案覆盖真实双输出的焦点、数字工作区归属、额外/来访工作区、动态同步、输出移除后
合并，以及设置不同缩放时的界面显示。程序调用全局入口不代表物理 Win 按住/松开时序
通过。本机 `wtype` 曾无法稳定复现 Win 按住状态，不能据此宣称物理键盘释放验收完成。
实体显示器驱动、线缆插拔和物理键盘时序仍需对应的实际测试。

普通命名工作区（例如 `a`）按当前约定暂不适配，见 [docs/known-issues.md](docs/known-issues.md)。
来访工作区与本地工作区可能有重复的 `1–9、0` 角标；这是当前跟随 Omarchy 顶部栏的
显示规则，内部仍必须使用全局 ID 区分，不把重复角标误判为重复工作区。
