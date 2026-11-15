import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons as Commons
import qs.Ui as Ui
import "controllers" as Controllers
import "adapters" as Adapters
import "components" as Components
import "previews" as Previews
import "generated/Logic.mjs" as Logic

Item {
    id: root
    property var shell: null
    property var manifest: null
    property bool opened: false
    readonly property bool panelVisible: opened && !panelRevealDelay.running
    property string mode: "window"
    property var snapshot: ({windows: [], workspaces: [], monitors: []})
    property var candidates: []
    property var request: ({holdToConfirm: false, globalInput: false})
    property var pendingActivation: null
    property var pendingOpenRequest: null
    property string sourceMonitor: ""
    property string sourceWorkspace: ""
    property string originWindowKey: ""
    property bool windowsExpanded: false
    readonly property var selectedApplication: mode === "window" ? candidates[session.selectedIndex] || null : null
    readonly property var applicationWindows: selectedApplication ? selectedApplication.windows : []
    property string currentKey: ""
    property string errorKey: ""
    readonly property string pluginId: manifest ? manifest.id : "jessie.switchboard"
    readonly property bool bindingRequested: config.supported && config.settings.bindingsEnabled && desktopAdapter.available
    readonly property bool bindingReady: bindings.active

    function open(payloadJson: string): void {
        if (activation.busy || pendingActivation) { pendingOpenRequest = payloadJson; return }
        // qmllint disable missing-property
        const next = Logic.parseOpenRequest(payloadJson)
        // qmllint enable missing-property
        const nextMode = next.mode === "app-windows" ? "window" : next.mode
        if (opened && mode === nextMode) {
            request = next
            if (next.mode !== "window" || !next.holdToConfirm) panelRevealDelay.stop()
            if (next.mode === "app-windows") expandWindows(next.direction)
            else step(next.direction)
            return
        }
        if (opened) close()
        desktopAdapter.recordCurrentFocus()
        snapshot = desktopAdapter.snapshot(config.settings.slotsPerMonitor)
        sourceMonitor = snapshot.sourceMonitorKey || ""
        sourceWorkspace = snapshot.currentWorkspaceKey || ""
        originWindowKey = snapshot.currentWindowKey || ""
        request = next
        mode = nextMode
        windowsExpanded = false
        errorKey = config.supported && desktopAdapter.available ? "" : "status.unavailable"
        const currentWindow = snapshot.windows.find(function(w) { return w.key === snapshot.currentWindowKey })
        // qmllint disable missing-property
        currentKey = mode === "window" ? currentWindow ? Logic.applicationKey(currentWindow) : "" : snapshot.currentWorkspaceKey || ""
        // qmllint enable missing-property
        const history = mode === "window" ? desktopAdapter.windowHistory : desktopAdapter.workspaceHistory
        // qmllint disable missing-property
        candidates = errorKey ? [] : mode === "window" ? Logic.applicationCandidates(snapshot, history) : Logic.workspaceCandidates(snapshot, history)
        // qmllint enable missing-property
        // An empty application scope has no target; leave the surface and input alone.
        if (mode === "window" && !errorKey && candidates.length === 0) {
            dismiss()
            return
        }
        desktopAdapter.suppressHistory = true
        session.begin(next, {sourceMonitorKey: sourceMonitor, originWindowKey: snapshot.currentWindowKey, originWorkspaceKey: snapshot.currentWorkspaceKey})
        if (next.mode === "window" && next.holdToConfirm && !errorKey) panelRevealDelay.restart()
        else panelRevealDelay.stop()
        opened = true
        session.ready(candidates.map(function(c) { return c.key }), currentKey, false)
        if (next.mode === "app-windows") {
            const index = candidates.findIndex(function(c) { return c.key === root.currentKey })
            if (index < 0) { dismiss(); return }
            session.select(index)
            expandWindows(next.direction)
        }
        Qt.callLater(function() {
            if (!root.opened) return
            keyCatcher.forceActiveFocus()
            if (root.request.holdToConfirm) root.queryModifiers()
        })
    }
    function close(): void {
        opened = false
        panelRevealDelay.stop()
        modifierTimer.stop()
        session.cancel()
        windowSession.cancel()
        windowsExpanded = false
        candidates = []
        pendingOpenRequest = null
        if (!pendingActivation && !activation.busy) desktopAdapter.suppressHistory = false
    }
    function refreshDesktop(next: var): void {
        if (!opened) return
        if (!next.monitors.some(function(m) { return m.key === root.sourceMonitor })) { dismiss(); return }
        // Keep the opening screen as the source even if desktop focus changes.
        const scoped = Object.assign({}, next, {sourceMonitorKey: sourceMonitor,
            currentWorkspaceKey: mode === "window" ? sourceWorkspace : next.currentWorkspaceKey})
        if (JSON.stringify(scoped) !== JSON.stringify(snapshot)) snapshot = scoped
        if (mode === "workspace" && !errorKey) {
            // Reconcile arrivals, departures and renumbering against the locked
            // screen, keeping existing order and the selected global identity.
            // qmllint disable missing-property
            const fresh = Logic.reconcileWorkspaceCandidates(Object.assign({}, scoped, {currentWorkspaceKey: currentKey}),
                desktopAdapter.workspaceHistory, candidates.map(function(c) { return c.key }))
            // qmllint enable missing-property
            if (JSON.stringify(fresh) !== JSON.stringify(candidates)) {
                candidates = fresh
                session.refresh(fresh.map(function(c) { return c.key }))
            }
        } else if (mode === "window" && !errorKey) {
            // History and both navigation queues stay stable while the surface owns input.
            // qmllint disable missing-property
            const fresh = Logic.reconcileApplicationCandidates(Object.assign({}, scoped, {currentWindowKey: session.state.context.originWindowKey}),
                desktopAdapter.windowHistory, candidates.map(function(c) { return c.key }))
            // qmllint enable missing-property
            if (JSON.stringify(fresh) !== JSON.stringify(candidates)) {
                candidates = fresh
                session.refresh(fresh.map(function(c) { return c.key }))
                if (opened && windowsExpanded) windowSession.refresh(applicationWindows.map(function(w) { return w.key }))
            }
        }
    }
    function dismiss(): void {
        // Unmapping an exclusive layer can otherwise focus a different floating
        // window under the pointer. Restore the opening window after unmapping.
        if (opened && mode === "window" && !pendingActivation && !activation.busy) {
            const origin = snapshot.windows.find(function(w) { return w.key === root.originWindowKey
                && w.workspaceKey === root.sourceWorkspace && w.monitorKey === root.sourceMonitor })
            if (origin) {
                pendingActivation = {kind: "window", key: origin.key, monitorKey: sourceMonitor, workspaceKey: sourceWorkspace}
                activateTimer.restart()
            }
        }
        close()
        if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    }
    function step(direction: int): void {
        if (!opened) return
        windowsExpanded = false
        windowSession.cancel()
        session.step(direction)
    }
    function expandWindows(direction: int): void {
        if (!opened || mode !== "window" || !selectedApplication) return
        if (windowsExpanded) { windowSession.step(direction); return }
        windowsExpanded = true
        windowSession.begin({mode: "app-windows", direction: direction}, session.state.context)
        windowSession.ready(applicationWindows.map(function(w) { return w.key }), session.state.context.originWindowKey, false)
    }
    function select(index: int): void {
        windowsExpanded = false
        session.select(index)
        session.confirm()
    }
    function selectWindow(index: int): void {
        windowSession.select(index)
        windowSession.confirm()
    }
    function confirm(): void {
        if (windowsExpanded) windowSession.confirm()
        else session.confirm()
    }
    function commit(key: string): void {
        const candidate = candidates.find(function(c) { return c.key === key })
        if (!candidate) { dismiss(); return }
        // The application session is already committing here, so its selecting
        // index is gone. Resolve through the committed group, not the view.
        if (mode === "window") queueActivation({kind: "window", key: candidate.windows[0].key,
            monitorKey: sourceMonitor, workspaceKey: sourceWorkspace})
        else queueActivation({kind: "workspace", key: key, workspace: candidate})
    }
    function commitWindow(key: string): void {
        if (!applicationWindows.some(function(w) { return w.key === key })) { dismiss(); return }
        queueActivation({kind: "window", key: key, monitorKey: sourceMonitor, workspaceKey: sourceWorkspace})
    }
    function queueActivation(target: var): void {
        pendingActivation = target
        // Unmap the overlay and give Wayland a turn to relinquish exclusive keyboard focus.
        dismiss()
        activateTimer.restart()
    }
    function navigate(key: int): void {
        if (mode === "window") {
            if (key === Qt.Key_Down && !windowsExpanded) expandWindows(1)
            else if (key === Qt.Key_Up && windowsExpanded) { windowsExpanded = false; windowSession.cancel() }
            else if (key === Qt.Key_Left || key === Qt.Key_Right) {
                const delta = key === Qt.Key_Left ? -1 : 1
                if (windowsExpanded) windowSession.step(delta)
                else session.step(delta)
            }
            return
        }
        const columns = workspaceView.columns
        const direction = key === Qt.Key_Left ? "left" : key === Qt.Key_Right ? "right" : key === Qt.Key_Up ? "up" : "down"
        // qmllint disable missing-property
        session.select(Logic.navigateGrid(session.selectedIndex, candidates.length, columns, direction))
        // qmllint enable missing-property
    }
    function queryModifiers(): void {
        if (!opened || !request.holdToConfirm || modifierProc.running) return
        modifierProc.gestureId = session.state.sessionId
        const keys = mode === "window" ? ["Alt_L", "Alt_R"] : ["Super_L", "Super_R"]
        modifierProc.command = ["hyprctl", "repl", "print(hl.is_key_down(\"" + keys[0] + "\") or hl.is_key_down(\"" + keys[1] + "\"))"]
        modifierProc.running = true
    }
    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
    Components.Theme { id: theme }
    Previews.PreviewProvider { id: previews; adapter: desktopAdapter; active: root.panelVisible && (root.mode === "workspace" || root.windowsExpanded) }
    Controllers.ConfigController {
        id: config
        shell: root.shell
        pluginId: root.pluginId
        defaultBindingsEnabled: root.manifest ? root.manifest.defaultBindingsEnabled === true : false
        onInvalidConfig: root.dismiss()
    }
    Controllers.BindingsController { id: bindings; requested: root.bindingRequested; pluginId: root.pluginId }
    Adapters.HyprlandAdapter {
        id: desktopAdapter
        onDesktopChanged: {
            if (root.opened) root.refreshDesktop(desktopAdapter.snapshot(config.settings.slotsPerMonitor))
        }
    }
    Controllers.SessionController { id: session; onCommitRequested: function(key) { root.commit(key) }; onEmptyConfirmed: root.dismiss() }
    Controllers.SessionController { id: windowSession; onCommitRequested: function(key) { root.commitWindow(key) }; onEmptyConfirmed: root.dismiss() }
    Controllers.ActivationController {
        id: activation
        adapter: desktopAdapter
        slotsPerMonitor: config.settings.slotsPerMonitor
        onCompleted: function(success) {
            if (!success) console.warn("Switchboard: target activation failed")
            const next = root.pendingOpenRequest
            root.pendingOpenRequest = null
            if (next !== null) root.open(next)
        }
    }
    Timer {
        id: activateTimer
        interval: 20
        onTriggered: {
            const target = root.pendingActivation
            root.pendingActivation = null
            if (target) activation.activate(target)
        }
    }
    // Delay only the picture. The transparent surface already owns input, so
    // immediate Tab/Escape and Alt release still reach the current session.
    Timer { id: panelRevealDelay; interval: 100 }
    Timer { id: modifierTimer; interval: 45; repeat: true; running: root.opened && root.request.holdToConfirm; onTriggered: root.queryModifiers() }
    Timer {
        interval: 200
        repeat: true
        running: root.opened
        onTriggered: {
            // Pixel content streams through ScreencopyView; refresh geometry
            // separately for resizing and moving windows while the panel is open.
            Hyprland.refreshToplevels()
            const next = desktopAdapter.snapshot(config.settings.slotsPerMonitor)
            root.refreshDesktop(next)
        }
    }
    Process {
        id: modifierProc
        property int gestureId: -1
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.opened || modifierProc.gestureId !== session.state.sessionId) return
                if (text.trim() === "false") {
                    root.confirm()
                }
                // An unsupported query never commits by timeout. Enter and Esc remain available.
            }
        }
    }
    GlobalShortcut { appid: root.pluginId; name: "window-forward"; onPressed: root.open('{"mode":"window","direction":1,"holdToConfirm":true,"globalInput":true}') }
    GlobalShortcut { appid: root.pluginId; name: "window-backward"; onPressed: root.open('{"mode":"window","direction":-1,"holdToConfirm":true,"globalInput":true}') }
    GlobalShortcut { appid: root.pluginId; name: "app-windows-forward"; onPressed: root.open('{"mode":"app-windows","direction":1,"holdToConfirm":true,"globalInput":true}') }
    GlobalShortcut { appid: root.pluginId; name: "app-windows-backward"; onPressed: root.open('{"mode":"app-windows","direction":-1,"holdToConfirm":true,"globalInput":true}') }
    GlobalShortcut { appid: root.pluginId; name: "workspace-forward"; onPressed: root.open('{"mode":"workspace","direction":1,"holdToConfirm":true,"globalInput":true}') }
    GlobalShortcut { appid: root.pluginId; name: "workspace-backward"; onPressed: root.open('{"mode":"workspace","direction":-1,"holdToConfirm":true,"globalInput":true}') }

    Commons.ShellIpc {
        target: root.pluginId
        function status(): string { return JSON.stringify({ready: desktopAdapter.available && config.supported && (!root.bindingRequested || root.bindingReady), buildId: root.manifest ? root.manifest.buildId || root.manifest.developmentBuildId || "" : "", opened: root.opened, panelVisible: root.panelVisible, mode: root.mode, candidates: root.candidates.length, selectedIndex: session.selectedIndex, phase: session.phase, busy: activation.busy || root.pendingActivation !== null, bindings: root.bindingReady, sourceMonitor: root.sourceMonitor, sourceWorkspace: root.sourceWorkspace, windowsExpanded: root.windowsExpanded, windows: root.applicationWindows.length, selectedWindowIndex: windowSession.selectedIndex}) }
        function step(direction: int): void { root.step(direction < 0 ? -1 : 1) }
        function expand(direction: int): void { root.expandWindows(direction < 0 ? -1 : 1) }
        function confirm(): void { root.confirm() }
        function cancel(): void { root.dismiss() }
        function settings(json: string): bool { try { return config.save(JSON.parse(json)) } catch (error) { return false } }
    }

    Ui.OverlayWindow {
        id: overlay
        shown: root.opened
        shownKeyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        // Held Super would otherwise let compositor shortcuts consume arrows.
        // The inhibitor belongs to this surface and is released when it closes.
        ShortcutInhibitor {
            id: shortcutInhibitor
            window: overlay
            enabled: root.opened
        }
        Rectangle {
            opacity: root.panelVisible ? 1 : 0
            x: (parent.width - width) / 2
            y: root.mode === "workspace" ? (parent.height - height) / 2
                : Math.min((parent.height - windowView.stripHeight) / 2, parent.height - height - 32)
            width: Math.min(parent.width - 48, root.mode === "workspace" ? workspaceView.preferredWidth + 40 : windowView.preferredWidth)
            height: Math.min(parent.height - 64, root.mode === "workspace" ? workspaceView.preferredHeight + 40 : windowView.preferredHeight)
            radius: theme.cornerRadius
            color: root.mode === "workspace" ? theme.backgroundColor : "transparent"
            border.color: theme.borderColor
            border.width: root.mode === "workspace" ? 1 : 0
            Item {
                id: keyCatcher
                anchors { fill: parent; margins: root.mode === "workspace" ? 20 : 0 }
                focus: true
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) root.dismiss()
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.confirm()
                    else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        // While inhibited, Tab reaches Qt instead of the global shortcut.
                        if (!root.request.globalInput || shortcutInhibitor.active)
                            root.step((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
                    } else if (root.mode === "window" && [Qt.Key_QuoteLeft, Qt.Key_AsciiTilde,
                        Qt.Key_Dead_Grave, Qt.Key_Dead_Tilde].indexOf(event.key) >= 0) {
                        if (!root.request.globalInput || shortcutInhibitor.active)
                            root.expandWindows(event.modifiers & Qt.ShiftModifier ? -1 : 1)
                    } else if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].indexOf(event.key) >= 0) root.navigate(Commons.Util.readingKey(event))
                    else return
                    event.accepted = true
                }
                Components.WindowSwitcher {
                    id: windowView
                    anchors.fill: parent
                    visible: root.panelVisible && root.mode === "window"
                    candidates: root.mode === "window" ? root.candidates : []
                    selectedIndex: session.selectedIndex
                    windowCandidates: root.applicationWindows
                    selectedWindowIndex: windowSession.selectedIndex
                    windowsExpanded: root.windowsExpanded
                    previewProvider: previews
                    emptyText: strings.t(root.errorKey || "window.empty")
                    foregroundColor: theme.foregroundColor
                    onCandidateClicked: function(index) { root.select(index) }
                    onWindowClicked: function(index) { root.selectWindow(index) }
                }
                Components.WorkspaceSwitcher {
                    id: workspaceView
                    anchors.fill: parent
                    maximumHeight: Math.max(0, overlay.height - 64 - 40)
                    visible: root.mode === "workspace"
                    candidates: root.mode === "workspace" ? root.candidates : []
                    snapshot: root.snapshot
                    selectedIndex: session.selectedIndex
                    previewProvider: previews
                    showMonitorLabels: config.settings.showMonitorLabels
                    emptyText: strings.t(root.errorKey || "workspace.none")
                    foregroundColor: theme.foregroundColor
                    onCandidateClicked: function(index) { root.select(index) }
                }
            }
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.opened && !Quickshell.screens.some(function(s) { return s.name === root.sourceMonitor })) root.dismiss()
        }
    }
    Component.onDestruction: {
        activateTimer.stop()
        panelRevealDelay.stop()
        modifierTimer.stop()
        activation.cancel()
    }
}
