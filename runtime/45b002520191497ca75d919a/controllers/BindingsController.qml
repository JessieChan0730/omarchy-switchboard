import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../generated/Logic.mjs" as Logic

Item {
    id: controller
    property bool requested: false
    property string pluginId: "jessie.switchboard"
    property bool active: false
    readonly property double issuedAt: Date.now()
    readonly property string token: String(issuedAt) + "-" + String(Math.random())
    readonly property string scriptPath: decodeURIComponent(String(Qt.resolvedUrl("../bindings.lua")).replace(/^file:\/\//, ""))
    property bool destroying: false

    function release(): void {
        active = false
        // execDetached survives destruction of the owning overlay. The token
        // guard prevents an old instance from removing its successor's keys.
        // qmllint disable missing-property
        const code = "local s=_G.switchboard_runtime; if s then s:release(" + Logic.luaString(token) + ") end"
        // qmllint enable missing-property
        Quickshell.execDetached(["hyprctl", "eval", code])
    }

    function update(): void {
        if (destroying || !requested || operation.running) return
        // qmllint disable missing-property
        const path = Logic.luaString(scriptPath)
        const owner = Logic.luaString(token)
        const plugin = Logic.luaString(pluginId)
        // qmllint enable missing-property
        const code = active
            ? "local s=_G.switchboard_runtime; print(s and s:renew(" + owner + ") or false)"
            : "local s=_G.switchboard_runtime; if not s or s.path~=" + path
                + " then s=assert(loadfile(" + path + "))(); s.path=" + path
                + " end; print(s:claim(" + owner + "," + issuedAt + "," + plugin + "))"
        operation.command = ["hyprctl", "repl", code]
        operation.running = true
    }

    onRequestedChanged: {
        if (requested) applyTimer.restart()
        else { applyTimer.stop(); release() }
    }
    Timer { id: applyTimer; interval: 150; onTriggered: controller.update() }
    Timer { interval: 2000; repeat: true; running: controller.requested; onTriggered: controller.update() }
    Process {
        id: operation
        property bool successful: false
        stdout: StdioCollector { onStreamFinished: operation.successful = text.trim() === "true" }
        onStarted: successful = false
        onExited: function(code) {
            controller.active = controller.requested && code === 0 && successful
            if (!controller.requested) controller.release()
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name === "configreloaded") {
                controller.active = false
                if (controller.requested) applyTimer.restart()
            }
        }
    }
    Component.onCompleted: { if (requested) applyTimer.restart() }
    Component.onDestruction: {
        destroying = true
        applyTimer.stop()
        if (requested || active) release()
    }
}
