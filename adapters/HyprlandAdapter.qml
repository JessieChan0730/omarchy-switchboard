import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../generated/Logic.mjs" as Logic

Item {
    id: adapter
    readonly property bool available: Hyprland.monitors.values.length > 0 && Hyprland.usingLua
    property var blocks: ({})
    property var identities: ({})
    property var merged: ({})
    property var lifetimes: ({})
    property int nextLifetime: 0
    property var windowHistory: []
    property var workspaceHistory: []
    property bool suppressHistory: false
    signal desktopChanged()
    signal realFocusRecorded()

    function readBlocks(text: string): void {
        const next = {}, ids = {}
        text.split("\n").forEach(function(line) {
            const fields = line.split("\t")
            if (fields.length >= 3 && fields[1] && /^\d+$/.test(fields[0])) {
                next[fields[1]] = Number(fields[0])
                ids[fields[1]] = fields.slice(2).join("\t")
            }
        })
        adapter.blocks = next
        adapter.identities = ids
        adapter.desktopChanged()
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: adapter.readBlocks(text())
        onLoadFailed: adapter.readBlocks("")
    }
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces-merged"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const next = {}
            text().split("\n").forEach(function(line) {
                const fields = line.split("\t")
                if (fields.length >= 3) next[fields[0]] = fields[2]
            })
            adapter.merged = next
            adapter.desktopChanged()
        }
        onLoadFailed: adapter.merged = ({})
    }

    function workspaceKey(workspace: var): string {
        if (!workspace) return ""
        return workspace.id > 0 ? "workspace:" + workspace.id : "workspace:name:" + workspace.name
    }

    function syncLifetimes(): void {
        const next = {}
        Hyprland.toplevels.values.forEach(function(win) {
            const old = adapter.lifetimes[win.address]
            next[win.address] = old && old.handle === win ? old : { handle: win, serial: ++adapter.nextLifetime }
        })
        adapter.lifetimes = next
    }

    function windowKey(win: var): string {
        const life = win ? adapter.lifetimes[win.address] : null
        return life ? "window:" + win.address + ":" + life.serial : ""
    }

    function windowHandle(key: string): var {
        const values = Hyprland.toplevels.values
        for (let i = 0; i < values.length; i++) if (adapter.windowKey(values[i]) === key) return values[i]
        return null
    }

    function snapshot(slots: int): var {
        adapter.syncLifetimes()
        const monitors = Hyprland.monitors.values.filter(function(m) {
            const mirror = (m.lastIpcObject || {}).mirrorOf
            return !mirror || mirror === "none"
        }).map(function(m) {
            const ipc = m.lastIpcObject || {}
            const scale = m.scale > 0 ? m.scale : 1
            const transform = Number(ipc.transform || 0)
            const rotated = transform % 2 === 1
            // Match the bar's fallback until Omarchy writes the monitor map.
            const activeId = m.activeWorkspace ? m.activeWorkspace.id : 1
            const block = adapter.blocks[m.name] === undefined ? Math.max(0, Math.floor((activeId - 1) / 10)) : adapter.blocks[m.name]
            return { key: m.name, connector: m.name, physicalIdentity: adapter.identities[m.name] || null,
                slotStart: block * 10 + 1,
                geometry: { x: m.x, y: m.y, width: (rotated ? m.height : m.width) / scale, height: (rotated ? m.width : m.height) / scale },
                scale: scale, transform: transform }
        }).sort(function(a, b) { return (a.slotStart || 100000) - (b.slotStart || 100000) || a.connector.localeCompare(b.connector) })
        const workspaces = Hyprland.workspaces.values.map(function(w) {
            const monitor = w.monitor ? w.monitor.name : ""
            const local = w.id > 0 ? (w.id - 1) % 10 + 1 : null
            const origin = adapter.merged[String(w.id)]
            let home = monitor
            if (origin) Object.keys(adapter.identities).forEach(function(name) { if (adapter.identities[name] === origin) home = name })
            return { key: adapter.workspaceKey(w), id: w.id, name: w.name, localSlot: local, monitorKey: monitor,
                homeMonitorKey: home, isSpecial: w.name === "special" || w.name.indexOf("special:") === 0, exists: true, canCreate: false }
        })
        const windows = Hyprland.toplevels.values.filter(function(w) {
            const ipc = w.lastIpcObject || {}
            return ipc.mapped !== false && String(ipc.class || "").indexOf("jessie.switchboard") !== 0
        }).map(function(w) {
            const ipc = w.lastIpcObject || {}, at = ipc.at || [0, 0], size = ipc.size || [0, 0]
            let address = String(w.address)
            if (address.indexOf("0x") !== 0) address = "0x" + address
            return { key: adapter.windowKey(w), address: address, title: w.title || "", appId: ipc.class || (w.wayland ? w.wayland.appId : ""),
                workspaceKey: adapter.workspaceKey(w.workspace), monitorKey: w.monitor ? w.monitor.name : "",
                geometry: { x: at[0], y: at[1], width: size[0], height: size[1] }, floating: ipc.floating === true,
                fullscreen: Number(ipc.fullscreen || 0) > 0, pinned: ipc.pinned === true,
                focusHistoryID: typeof ipc.focusHistoryID === "number" ? ipc.focusHistoryID : null }
        })
        // qmllint disable missing-property
        return Logic.parseSnapshot({ windows: windows, workspaces: workspaces, monitors: monitors,
            currentWindowKey: adapter.windowKey(Hyprland.activeToplevel), currentWorkspaceKey: adapter.workspaceKey(Hyprland.focusedWorkspace),
            sourceMonitorKey: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : null })
        // qmllint enable missing-property
    }

    function recordCurrentFocus(): void {
        if (adapter.suppressHistory) return
        const snap = adapter.snapshot(10)
        // qmllint disable missing-property
        if (snap.windows.some(function(w) { return w.key === snap.currentWindowKey }))
            adapter.windowHistory = Logic.recordFocus(adapter.windowHistory, snap.currentWindowKey)
        if (snap.workspaces.some(function(w) { return w.key === snap.currentWorkspaceKey && !w.isSpecial }))
            adapter.workspaceHistory = Logic.recordFocus(adapter.workspaceHistory, snap.currentWorkspaceKey)
        // qmllint enable missing-property
        adapter.realFocusRecorded()
    }

    Timer { id: focusTimer; interval: 15; onTriggered: adapter.recordCurrentFocus() }
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() { focusTimer.restart() }
        function onFocusedWorkspaceChanged() { focusTimer.restart() }
        function onFocusedMonitorChanged() { focusTimer.restart() }
        function onRawEvent(event) {
            const name = event ? String(event.name) : ""
            if (["openwindow", "closewindow", "movewindowv2", "moveworkspacev2", "workspacev2", "monitoradded", "monitorremoved", "changeworkspaceid", "fullscreen", "configreloaded"].indexOf(name) >= 0) {
                if (["moveworkspacev2", "workspacev2", "changeworkspaceid", "fullscreen", "configreloaded"].indexOf(name) >= 0) {
                    Hyprland.refreshWorkspaces()
                    Hyprland.refreshMonitors()
                    Hyprland.refreshToplevels()
                }
                adapter.syncLifetimes()
                adapter.desktopChanged()
                focusTimer.restart()
            }
        }
    }
    Component.onCompleted: {
        const snap = adapter.snapshot(10)
        adapter.windowHistory = snap.windows.slice().sort(function(a, b) { return (a.focusHistoryID === null ? 100000 : a.focusHistoryID) - (b.focusHistoryID === null ? 100000 : b.focusHistoryID) }).map(function(w) { return w.key })
        adapter.recordCurrentFocus()
    }
}
