import QtQuick

QtObject {
    id: controller
    property bool enabled: false
    property string applicationKey: ""
    property int windowCount: 0
    readonly property bool eligible: enabled && applicationKey.length > 0 && windowCount > 1
    signal expandRequested(string key)

    // Candidate metadata may refresh while the selection stays put. Only a
    // different application restarts the dwell; closing the panel stops it.
    onApplicationKeyChanged: {
        if (eligible) dwell.restart()
    }
    property Timer dwell: Timer {
        interval: 700
        running: controller.eligible
        onTriggered: controller.expandRequested(controller.applicationKey)
    }
}
