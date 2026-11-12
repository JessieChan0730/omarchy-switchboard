import QtQuick

QtObject {
    required property var adapter
    property bool active: false
    readonly property bool available: active && adapter.available

    function sourceForWindow(key: string): var {
        if (!available) return null
        // Resolve the complete lifetime key; a reused address must never show
        // the contents of a different window.
        const handle = adapter.windowHandle(key)
        return handle ? handle.wayland : null
    }
}
