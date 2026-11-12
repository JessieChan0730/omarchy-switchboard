import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: provider
    required property var adapter
    property bool active: false
    readonly property bool available: active && adapter.available
    property string backgroundPath: ""

    function refreshBackground(): void {
        if (available && !backgroundLookup.running) backgroundLookup.running = true
    }
    onAvailableChanged: {
        if (available) refreshBackground()
        else backgroundPath = ""
    }
    Process {
        id: backgroundLookup
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/omarchy/current/background"]
        stdout: StdioCollector { id: backgroundOutput }
        onExited: function(exitCode) {
            if (provider.available) provider.backgroundPath = exitCode === 0 ? backgroundOutput.text.trim() : ""
        }
    }
    // Resolve the symlink again while visible so a wallpaper change follows
    // the desktop. Closed panels keep neither decoded images nor polling.
    Timer { interval: 2000; repeat: true; running: provider.available; onTriggered: provider.refreshBackground() }

    function sourceForWindow(key: string): var {
        if (!available) return null
        // Resolve the complete lifetime key; a reused address must never show
        // the contents of a different window.
        const handle = adapter.windowHandle(key)
        return handle ? handle.wayland : null
    }
}
