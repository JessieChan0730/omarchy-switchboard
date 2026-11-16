import QtQuick

QtObject {
    id: controller
    property bool active: false
    property string sourceKey: ""
    property bool hasContent: false
    property bool fallbackReady: false
    readonly property bool ready: active && (hasContent || fallbackReady)

    onActiveChanged: fallbackReady = false
    onSourceKeyChanged: {
        fallbackReady = false
        if (active && !hasContent) firstFrame.restart()
    }
    property Timer firstFrame: Timer {
        // Give normal captures their first frame before showing a fallback.
        // An unavailable stream must never keep the switcher invisible.
        interval: 150
        running: controller.active && !controller.hasContent && !controller.fallbackReady
        onTriggered: controller.fallbackReady = true
    }
}
