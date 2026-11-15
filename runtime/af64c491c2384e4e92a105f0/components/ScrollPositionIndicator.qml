import QtQuick

Item {
    id: indicator
    objectName: "scrollPositionIndicator"
    required property color foregroundColor
    property real contentHeight: 0
    property real contentOffset: 0
    readonly property real maximumOffset: Math.max(0, contentHeight - height)
    readonly property bool scrollable: height > 0 && maximumOffset > 1
    readonly property real position: maximumOffset > 0 ? Math.max(0, Math.min(1, contentOffset / maximumOffset)) : 0
    readonly property real thumbLength: scrollable ? Math.min(height, Math.max(24, height * height / contentHeight)) : 0
    readonly property real thumbOffset: (height - thumbLength) * position
    width: 4
    visible: scrollable

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: indicator.foregroundColor
        opacity: 0.1
    }
    Rectangle {
        y: indicator.thumbOffset
        width: parent.width
        height: indicator.thumbLength
        radius: width / 2
        color: indicator.foregroundColor
        opacity: 0.45
    }
}
