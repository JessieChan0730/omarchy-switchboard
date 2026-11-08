# 基础架构

QML 负责 Qt 对象、界面和信号；TypeScript 负责普通数据与纯逻辑；Lua 预留快捷键接入。
业务 TypeScript 仅使用 ES2016 标准类型，构建脚本使用独立 Node 类型环境。

`src/logic/index.ts` 是 QML 调用入口。构建生成 `generated/Logic.mjs`，并将 QML、
ESM、Lua 和翻译组装到 `dist/plugin/`；根目录中的 `generated/` 仅供开发和编辑器使用。
Qt Quick Test 导入发布目录中的同一份 ESM，验证真实 Qt 运行环境。

`qmllint` 以零警告阈值检查插件 QML。它无法推断 esbuild 的 ESM 导出列表，以及
Omarchy 以 `QtObject` 暴露的嵌套主题字段；这些边界采用局部的 `missing-property`
注释，主题访问集中在 `components/Theme.qml`。ESM 函数调用由 Qt 测试验证，
其余 QML 检查继续启用；主题与覆盖层仍需在实际宿主中验收。

显示文本复用 `components/PlainText.qml`，Qt 渲染测试验证类似 HTML 的窗口标题
仍以原始文字展示，防止 Qt 将动态标题当作富文本。

当前已提供共享记录/协议类型、配置校验、循环索引、MRU 数据操作、会话准备/取消和
逻辑坐标换算。它们是后续实现的基础函数，不代表完整窗口/工作区切换功能。

`HyprlandAdapter`、`ActivationController`、`PreviewProvider` 明确报告能力尚不可用。
`Overlay` 可作为宿主中的开发预览入口，界面和主题行为还需在实际 shell 中验收。
尚无全局按键注册、截图、目标激活或后台轮询。

P0 优先验证输入时序与捕获能力，再补齐 selecting/committing 转换、窗口记录校验、
真实历史、焦点交接和缓存。基础版采用纯 shell 插件，当前无需创建 `native/`。
