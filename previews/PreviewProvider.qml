import QtQuick

QtObject {
    property int generation: 0
    readonly property bool available: false

    function stop(): void {
        generation += 1
    }

    // P0: add ScreencopyView capture and stale-callback rejection.
    // P3: implement measured LRU budgets; no screenshot buffers exist yet.
}
