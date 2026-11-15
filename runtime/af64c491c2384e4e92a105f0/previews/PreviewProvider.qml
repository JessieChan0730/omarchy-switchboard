import QtQuick
import Quickshell
import Quickshell.Io
import "../controllers" as Controllers

Item {
    id: provider
    required property var adapter
    property bool active: false
    readonly property bool available: active && adapter.available
    property string backgroundLink: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
    property string backgroundCacheDirectory: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache")
        + "/omarchy-switchboard/backgrounds"
    readonly property string backgroundPath: backgroundCache.path
    readonly property bool backgroundReady: backgroundCache.ready
    property string wallpaperPath: ""
    property bool refreshPending: false

    function refreshBackground(): void {
        if (!adapter.available) return
        if (backgroundLookup.running) { refreshPending = true; return }
        backgroundLookup.running = true
    }
    onActiveChanged: if (active) refreshBackground()
    Component.onCompleted: refreshBackground()
    Controllers.BackgroundCacheController { id: backgroundCache }
    Connections {
        target: provider.adapter
        function onAvailableChanged() {
            if (provider.adapter.available) provider.refreshBackground()
            else { provider.wallpaperPath = ""; backgroundCache.requestedPath = "" }
        }
    }
    FileView {
        path: provider.backgroundLink
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: provider.refreshBackground()
    }
    Process {
        id: backgroundLookup
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("background_cache.py").toString().replace(/^file:\/\//, "")),
            provider.backgroundLink, provider.backgroundCacheDirectory]
        stdout: StdioCollector { id: backgroundOutput }
        onExited: function(exitCode) {
            if (!provider.adapter.available) return
            try {
                const result = JSON.parse(backgroundOutput.text)
                if (exitCode === 0 && result.retry === true) provider.refreshPending = true
                else {
                    provider.wallpaperPath = exitCode === 0 ? result.source || "" : ""
                    backgroundCache.requestedPath = exitCode === 0 ? result.path || "" : ""
                }
            } catch (error) {
                provider.wallpaperPath = ""
                backgroundCache.requestedPath = ""
            }
            if (provider.refreshPending) {
                provider.refreshPending = false
                Qt.callLater(provider.refreshBackground)
            }
        }
    }
    // Prepare even while closed. Polling also catches same-path replacement
    // and symlink changes that a file watcher cannot observe reliably.
    Timer { interval: 2000; repeat: true; running: provider.adapter.available; onTriggered: provider.refreshBackground() }

    function sourceForWindow(key: string): var {
        if (!available) return null
        // Resolve the complete lifetime key; a reused address must never show
        // the contents of a different window.
        const handle = adapter.windowHandle(key)
        return handle ? handle.wayland : null
    }
}
