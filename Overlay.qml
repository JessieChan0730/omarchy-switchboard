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
import "generated/Logic.mjs" as Logic

Item {
    id: root
    property var shell: null
    property var manifest: null
    property bool opened: false
    property string mode: "window"
    property var snapshot: ({windows: [], workspaces: [], monitors: []})
    property var candidates: []
    property var request: ({holdToConfirm: false, globalInput: false})
    property var pendingActivation: null
    property var pendingOpenRequest: null
    property bool createSelected: false
    property string sourceMonitor: ""
    property string currentKey: ""
    property string previousKey: ""
    property string errorKey: ""
    readonly property string pluginId: manifest ? manifest.id : "jessie.switchboard"
    readonly property string leaseToken: String(Date.now()) + "-" + String(Math.random())
    readonly property bool bindingReady: config.supported && config.settings.bindingsEnabled && desktopAdapter.available
    // qmllint disable missing-property
    readonly property var createTarget: Logic.newWorkspace(snapshot, sourceMonitor, config.settings.slotsPerMonitor)
    // qmllint enable missing-property

    function open(payloadJson: string): void {
        if (activation.busy || pendingActivation) { pendingOpenRequest = payloadJson; return }
        // qmllint disable missing-property
        const next = Logic.parseOpenRequest(payloadJson)
        // qmllint enable missing-property
        if (opened && mode === next.mode) { request = next; step(next.direction); return }
        if (opened) close()
        desktopAdapter.recordCurrentFocus()
        snapshot = desktopAdapter.snapshot(config.settings.slotsPerMonitor)
        sourceMonitor = snapshot.sourceMonitorKey || ""
        request = next
        mode = next.mode
        errorKey = config.supported && desktopAdapter.available ? "" : "status.unavailable"
        currentKey = mode === "window" ? snapshot.currentWindowKey || "" : snapshot.currentWorkspaceKey || ""
        const history = mode === "window" ? desktopAdapter.windowHistory : desktopAdapter.workspaceHistory
        previousKey = history.find(function(k) { return k !== currentKey }) || ""
        // qmllint disable missing-property
        candidates = errorKey ? [] : mode === "window" ? Logic.windowCandidates(snapshot, history) : Logic.workspaceCandidates(snapshot, history, config.settings.slotsPerMonitor)
        // qmllint enable missing-property
        createSelected = false
        desktopAdapter.suppressHistory = true
        session.begin(next, {sourceMonitorKey: sourceMonitor, originWindowKey: snapshot.currentWindowKey, originWorkspaceKey: snapshot.currentWorkspaceKey})
        opened = true
        const occupiedFirst = mode === "workspace" && candidates.some(function(w) { return w.windowKeys.length > 0 }) && !candidates.some(function(w) { return w.key === currentKey && w.windowKeys.length > 0 })
        session.ready(candidates.map(function(c) { return c.key }), currentKey, occupiedFirst)
        Qt.callLater(function() {
            if (!root.opened) return
            keyCatcher.forceActiveFocus()
            if (root.request.holdToConfirm) root.queryModifiers()
        })
    }
    function close(): void {
        opened = false
        modifierTimer.stop()
        session.cancel()
        candidates = []
        pendingOpenRequest = null
        if (!pendingActivation && !activation.busy) desktopAdapter.suppressHistory = false
    }
    function dismiss(): void {
        close()
        if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    }
    function step(direction: int): void {
        if (!opened) return
        createSelected = false
        session.step(direction)
    }
    function select(index: int): void {
        createSelected = false
        session.select(index)
        session.confirm()
    }
    function confirm(): void {
        if (createSelected) createWorkspace()
        else session.confirm()
    }
    function commit(key: string): void {
        const candidate = candidates.find(function(c) { return c.key === key })
        if (!candidate) { dismiss(); return }
        queueActivation({kind: mode, key: key, workspace: mode === "workspace" ? candidate : null})
    }
    function queueActivation(target: var): void {
        pendingActivation = target
        // Unmap the overlay and give Wayland a turn to relinquish exclusive keyboard focus.
        dismiss()
        activateTimer.restart()
    }
    function createWorkspace(): void {
        if (!opened || !createTarget) return
        queueActivation({kind: "workspace", key: createTarget.key, workspace: createTarget})
    }
    function previous(kind: string): void {
        if (opened || activation.busy || pendingActivation) return
        desktopAdapter.recordCurrentFocus()
        const snap = desktopAdapter.snapshot(config.settings.slotsPerMonitor)
        // qmllint disable missing-property
        const valid = kind === "window" ? snap.windows : Logic.fillWorkspaceSlots(snap, config.settings.slotsPerMonitor)
        const key = Logic.previousObject(kind === "window" ? desktopAdapter.windowHistory : desktopAdapter.workspaceHistory,
            kind === "window" ? snap.currentWindowKey || "" : snap.currentWorkspaceKey || "", valid.map(function(c) { return c.key }))
        // qmllint enable missing-property
        if (!key) return
        desktopAdapter.suppressHistory = true
        queueActivation({kind: kind, key: key, workspace: kind === "workspace" ? valid.find(function(w) { return w.key === key }) : null})
    }
    function navigate(key: int): void {
        const columns = mode === "workspace" ? workspaceView.columns : windowView.columns
        if (createSelected) {
            if (key === Qt.Key_Up) { createSelected = false; session.select(Math.max(0, candidates.length - 1)) }
            return
        }
        const delta = key === Qt.Key_Left ? -1 : key === Qt.Key_Right ? 1 : key === Qt.Key_Up ? -columns : columns
        const index = session.selectedIndex + delta
        if (mode === "workspace" && key === Qt.Key_Down && index >= candidates.length) createSelected = true
        else session.select(Math.max(0, Math.min(candidates.length - 1, index)))
    }
    function queryModifiers(): void {
        if (!opened || !request.holdToConfirm || modifierProc.running) return
        modifierProc.gestureId = session.state.sessionId
        const keys = mode === "window" ? ["Alt_L", "Alt_R"] : ["Super_L", "Super_R"]
        modifierProc.command = ["hyprctl", "repl", "print(hl.is_key_down(\"" + keys[0] + "\") or hl.is_key_down(\"" + keys[1] + "\"))"]
        modifierProc.running = true
    }
    function renewLease(): void {
        if (leaseProc.running) return
        // qmllint disable missing-property
        const quote = Logic.luaString
        leaseProc.command = ["hyprctl", "eval", bindingReady
            ? "_G.switchboard_lease={token=" + quote(leaseToken) + ",expires=os.time()+6}"
            : "if _G.switchboard_lease and _G.switchboard_lease.token==" + quote(leaseToken) + " then _G.switchboard_lease=nil end"]
        // qmllint enable missing-property
        leaseProc.running = true
    }
    onBindingReadyChanged: renewLease()

    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
    Components.Theme { id: theme }
    Controllers.ConfigController { id: config; shell: root.shell; pluginId: root.pluginId; onInvalidConfig: root.dismiss() }
    Adapters.HyprlandAdapter {
        id: desktopAdapter
        onDesktopChanged: {
            if (root.opened && !desktopAdapter.snapshot(config.settings.slotsPerMonitor).monitors.some(function(m) { return m.key === root.sourceMonitor })) root.dismiss()
        }
    }
    Controllers.SessionController { id: session; onCommitRequested: function(key) { root.commit(key) }; onEmptyConfirmed: root.dismiss() }
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
    Timer { id: modifierTimer; interval: 45; repeat: true; running: root.opened && root.request.holdToConfirm; onTriggered: root.queryModifiers() }
    Process {
        id: modifierProc
        property int gestureId: -1
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.opened || modifierProc.gestureId !== session.state.sessionId) return
                if (text.trim() === "false") {
                    if (root.createSelected) root.dismiss()
                    else session.confirm()
                }
                // An unsupported query never commits by timeout. Enter and Esc remain available.
            }
        }
    }
    Timer { interval: 2000; repeat: true; running: root.bindingReady; onTriggered: root.renewLease() }
    Process { id: leaseProc }

    GlobalShortcut { appid: root.pluginId; name: "window-forward"; onPressed: root.open('{"mode":"window","direction":1,"holdToConfirm":true,"globalInput":true}') }
    GlobalShortcut { appid: root.pluginId; name: "window-backward"; onPressed: root.open('{"mode":"window","direction":-1,"holdToConfirm":true,"globalInput":true}') }
    GlobalShortcut { appid: root.pluginId; name: "workspace-forward"; onPressed: root.open('{"mode":"workspace","direction":1,"holdToConfirm":true,"globalInput":true}') }
    GlobalShortcut { appid: root.pluginId; name: "workspace-backward"; onPressed: root.open('{"mode":"workspace","direction":-1,"holdToConfirm":true,"globalInput":true}') }
    GlobalShortcut { appid: root.pluginId; name: "previous-window"; onPressed: root.previous("window") }
    GlobalShortcut { appid: root.pluginId; name: "previous-workspace"; onPressed: root.previous("workspace") }

    Commons.ShellIpc {
        target: root.pluginId
        function status(): string { return JSON.stringify({ready: desktopAdapter.available && config.supported, buildId: root.manifest ? root.manifest.developmentBuildId || "" : "", opened: root.opened, mode: root.mode, candidates: root.candidates.length, selectedIndex: session.selectedIndex, phase: session.phase, busy: activation.busy || root.pendingActivation !== null, bindings: root.bindingReady, sourceMonitor: root.sourceMonitor}) }
        function step(direction: int): void { root.step(direction < 0 ? -1 : 1) }
        function confirm(): void { root.confirm() }
        function cancel(): void { root.dismiss() }
        function previous(kind: string): void { if (kind === "window" || kind === "workspace") root.previous(kind) }
        function settings(json: string): bool { try { return config.save(JSON.parse(json)) } catch (error) { return false } }
    }

    Ui.OverlayWindow {
        id: overlay
        shown: root.opened
        shownKeyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 1000)
            height: Math.min(parent.height - 64, root.mode === "workspace" ? 800 : 570)
            radius: theme.cornerRadius
            color: theme.backgroundColor
            border.color: theme.borderColor
            border.width: 1
            Item {
                id: keyCatcher
                anchors { fill: parent; margins: 20 }
                focus: true
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) root.dismiss()
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.confirm()
                    else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        if (!root.request.globalInput) root.step((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
                    } else if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].indexOf(event.key) >= 0) root.navigate(Commons.Util.readingKey(event))
                    else return
                    event.accepted = true
                }
                Components.PlainText {
                    id: title
                    width: parent.width
                    text: strings.t(root.mode === "workspace" ? "workspace.title" : "window.title") + " · " + root.sourceMonitor
                    color: theme.foregroundColor
                    font.family: theme.fontFamily
                    font.pixelSize: theme.titleSize
                }
                Components.WindowSwitcher {
                    id: windowView
                    anchors { top: title.bottom; topMargin: 16; left: parent.left; right: parent.right; bottom: hint.top; bottomMargin: 16 }
                    visible: root.mode === "window"
                    candidates: root.mode === "window" ? root.candidates : []
                    snapshot: root.snapshot
                    selectedIndex: session.selectedIndex
                    emptyText: strings.t(root.errorKey || "window.empty")
                    foregroundColor: theme.foregroundColor
                    showWorkspaceLabels: config.settings.showWorkspaceLabels
                    showMonitorLabels: config.settings.showMonitorLabels
                    onCandidateClicked: function(index) { root.select(index) }
                }
                Components.WorkspaceSwitcher {
                    id: workspaceView
                    anchors { top: title.bottom; topMargin: 16; left: parent.left; right: parent.right; bottom: hint.top; bottomMargin: 16 }
                    visible: root.mode === "workspace"
                    candidates: root.mode === "workspace" ? root.candidates : []
                    snapshot: root.snapshot
                    selectedIndex: session.selectedIndex
                    currentKey: root.currentKey
                    previousKey: root.previousKey
                    sourceMonitor: root.sourceMonitor
                    createSelected: root.createSelected
                    canCreate: root.createTarget !== null
                    showMonitorLabels: config.settings.showMonitorLabels
                    emptyText: strings.t(root.errorKey || "workspace.empty")
                    foregroundColor: theme.foregroundColor
                    onCandidateClicked: function(index) { root.select(index) }
                    onCreateClicked: root.createWorkspace()
                }
                Components.PlainText {
                    id: hint
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    text: strings.t(root.request.holdToConfirm ? "hint.hold" : "hint.select")
                    color: theme.foregroundColor
                    font.family: theme.fontFamily
                    font.pixelSize: theme.bodySize
                    wrapMode: Text.WordWrap
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
        modifierTimer.stop()
        activation.cancel()
        // qmllint disable missing-property
        Quickshell.execDetached(["hyprctl", "eval", "if _G.switchboard_lease and _G.switchboard_lease.token==" + Logic.luaString(leaseToken) + " then _G.switchboard_lease=nil end"])
        // qmllint enable missing-property
    }
}
