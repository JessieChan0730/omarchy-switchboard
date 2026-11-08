import QtQuick

QtObject {
    readonly property bool available: false
    signal snapshotUnavailable(int sessionId)

    function requestSnapshot(sessionId: int): void {
        snapshotUnavailable(sessionId)
    }

    // P0: normalize Quickshell.Hyprland models and monitor slot mappings.
    // Keep compositor QObjects here; pass validated plain records to TypeScript.
}
