import QtQuick
import Quickshell.Hyprland
import "../generated/Logic.mjs" as Logic

Item {
    id: controller
    required property var adapter
    property int slotsPerMonitor: 10
    property var pendingTarget: null
    property int attempts: 0
    readonly property bool busy: pendingTarget !== null
    signal completed(bool success)

    function dispatchTarget(): bool {
        if (!pendingTarget || !Hyprland.usingLua) return false
        const snap = adapter.snapshot(slotsPerMonitor)
        let workspace = pendingTarget.workspace
        let window = null
        if (pendingTarget.kind === "window") {
            window = snap.windows.find(function(w) { return w.key === pendingTarget.key })
            if (!window) return false
            workspace = snap.workspaces.find(function(w) { return w.key === window.workspaceKey })
        } else {
            // Reconstruct legal slots; stale or vanished named/guest targets are rejected.
            // qmllint disable missing-property
            workspace = Logic.workspaceActivationTarget(snap, pendingTarget.key,
                pendingTarget.workspace.monitorKey, Math.max(5, slotsPerMonitor))
            // qmllint enable missing-property
            if (!workspace || (!workspace.exists && !workspace.canCreate)) return false
        }
        const monitor = snap.monitors.find(function(m) { return m.key === workspace.monitorKey })
        if (!monitor) return false
        // qmllint disable missing-property
        const quote = Logic.luaString
        const target = workspace.id > 0 ? String(workspace.id) : "name:" + workspace.name
        Hyprland.dispatch("hl.dsp.focus({monitor=" + quote(monitor.connector) + "})")
        Hyprland.dispatch("hl.dsp.focus({workspace=" + quote(target) + "})")
        if (window) {
            Hyprland.dispatch("hl.dsp.focus({window=" + quote("address:" + window.address) + "})")
            Hyprland.dispatch("hl.dsp.window.alter_zorder({mode=\"top\",window=" + quote("address:" + window.address) + "})")
        }
        // qmllint enable missing-property
        return true
    }
    function activate(target: var): void {
        if (busy) return
        pendingTarget = target
        attempts = 0
        adapter.suppressHistory = true
        if (!dispatchTarget()) finish(false)
        else verify.restart()
    }
    function finish(success: bool): void {
        verify.stop()
        pendingTarget = null
        adapter.suppressHistory = false
        adapter.recordCurrentFocus()
        completed(success)
    }
    function cancel(): void {
        verify.stop()
        pendingTarget = null
        adapter.suppressHistory = false
    }
    Timer {
        id: verify
        interval: 60
        onTriggered: {
            if (!controller.pendingTarget) return
            const snap = controller.adapter.snapshot(controller.slotsPerMonitor)
            const success = controller.pendingTarget.kind === "window" ? snap.currentWindowKey === controller.pendingTarget.key : snap.currentWorkspaceKey === controller.pendingTarget.key
            if (success) controller.finish(true)
            else if (++controller.attempts < 3 && controller.dispatchTarget()) restart()
            else controller.finish(false)
        }
    }
    Component.onDestruction: controller.cancel()
}
