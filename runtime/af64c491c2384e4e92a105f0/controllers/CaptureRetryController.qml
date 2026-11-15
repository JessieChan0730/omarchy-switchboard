import QtQuick

Item {
    id: controller
    property bool active: false
    property var source: null
    property bool hasContent: false
    property bool stopped: false
    property int retryCount: 0
    readonly property int maximumRetries: 3
    readonly property bool captureEnabled: active && source !== null && !stopped

    function reset(): void {
        stopped = false
        retryCount = 0
    }
    function captureFailed(): void {
        // Ignore duplicate notifications and stops caused by unloading a view.
        if (captureEnabled) stopped = true
    }
    onSourceChanged: reset()
    onActiveChanged: reset()

    Timer {
        interval: 250 * Math.pow(2, controller.retryCount)
        running: controller.active && controller.source !== null && controller.stopped
            && controller.retryCount < controller.maximumRetries
        onTriggered: {
            if (!controller.active || controller.source === null || !controller.stopped) return
            controller.retryCount++
            controller.stopped = false
        }
    }
    Timer {
        // A first frame alone is not recovery: repeatedly stopping streams
        // must still exhaust the budget instead of retrying indefinitely.
        interval: 2000
        running: controller.captureEnabled && controller.hasContent && controller.retryCount > 0
        onTriggered: controller.retryCount = 0
    }
}
