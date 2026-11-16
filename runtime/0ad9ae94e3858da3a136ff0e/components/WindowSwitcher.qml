pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.Commons as Commons

Item {
    id: switcher
    required property string emptyText
    required property color foregroundColor
    required property var previewProvider
    property var candidates: []
    property var windowCandidates: []
    property int selectedIndex: -1
    property int selectedWindowIndex: -1
    property bool windowsExpanded: false
    property var applicationKeys: []
    property var windowKeys: []
    readonly property int stripHeight: 152
    readonly property real preferredWidth: Math.max(240, candidates.length * 104 + 32,
        windowsExpanded ? Math.min(3, windowCandidates.length) * 288 + 32 : 0)
    readonly property real preferredHeight: stripHeight + (windowsExpanded ? 256 : 0)
    readonly property real applicationContentX: apps.contentX - apps.originX
    readonly property real windowContentX: windows.contentX - windows.originX
    signal candidateClicked(int index)
    signal windowClicked(int index)
    Theme { id: theme }

    function reveal(): void {
        if (selectedIndex >= 0) apps.positionViewAtIndex(selectedIndex, ListView.Contain)
        if (selectedWindowIndex >= 0) windows.positionViewAtIndex(selectedWindowIndex, ListView.Contain)
    }
    onSelectedIndexChanged: Qt.callLater(reveal)
    onSelectedWindowIndexChanged: Qt.callLater(reveal)
    onCandidatesChanged: {
        const keys = candidates.map(function(app) { return app.key })
        if (JSON.stringify(keys) !== JSON.stringify(applicationKeys)) applicationKeys = keys
        Qt.callLater(reveal)
    }
    onWindowCandidatesChanged: {
        const keys = windowCandidates.map(function(window) { return window.key })
        if (JSON.stringify(keys) !== JSON.stringify(windowKeys)) windowKeys = keys
        Qt.callLater(reveal)
    }
    onWidthChanged: Qt.callLater(reveal)

    Rectangle {
        id: strip
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        width: Math.min(switcher.width, Math.max(240, switcher.candidates.length * 104 + 32))
        height: switcher.stripHeight
        radius: theme.cornerRadius + 6
        color: theme.backgroundColor
        border { width: 1; color: theme.borderColor }
        ListView {
            id: apps
            objectName: "applicationList"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            height: 120
            clip: true
            orientation: ListView.Horizontal
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentWidth > width
            model: switcher.applicationKeys
            delegate: Item {
                id: application
                required property string modelData
                required property int index
                readonly property var app: switcher.candidates.find(function(app) { return app.key === application.modelData }) || null
                readonly property var entry: app && app.appId ? DesktopEntries.heuristicLookup(app.appId) : null
                readonly property bool selected: index === switcher.selectedIndex
                width: switcher.candidates.length === 1 ? apps.width : 104
                height: apps.height
                Rectangle {
                    id: iconFrame
                    anchors { top: parent.top; topMargin: 4; horizontalCenter: parent.horizontalCenter }
                    width: 88; height: 88
                    radius: Math.min(16, theme.cornerRadius + 4)
                    color: application.selected ? Qt.rgba(theme.foregroundColor.r, theme.foregroundColor.g, theme.foregroundColor.b, 0.08) : "transparent"
                    border { width: application.selected ? 2 : 0; color: theme.accentColor }
                    Image {
                        id: icon
                        anchors.centerIn: parent
                        width: 60; height: 60
                        source: Quickshell.iconPath(application.entry && application.entry.icon ? application.entry.icon : "application-x-executable", true)
                        fillMode: Image.PreserveAspectFit
                    }
                    PlainText {
                        anchors.centerIn: parent
                        visible: icon.status !== Image.Ready
                        text: (application.app && application.app.appId || "?").slice(0, 2).toUpperCase()
                        color: theme.foregroundColor
                        font { family: theme.fontFamily; pixelSize: 24 }
                    }
                    Rectangle {
                        anchors { top: parent.top; right: parent.right; topMargin: 3; rightMargin: 3 }
                        visible: application.app !== null && application.app.windows.length > 1
                        width: Math.max(20, count.implicitWidth + 10); height: 20
                        radius: 10
                        color: application.selected ? theme.accentColor : theme.borderColor
                        PlainText {
                            id: count
                            anchors.centerIn: parent
                            text: Commons.I18n.formatNumber(application.app ? application.app.windows.length : 0)
                            color: application.selected ? theme.backgroundColor : theme.foregroundColor
                            font { family: theme.fontFamily; pixelSize: 11; bold: true }
                        }
                    }
                }
                PlainText {
                    objectName: "applicationName"
                    anchors { top: iconFrame.bottom; topMargin: 8; left: iconFrame.left; right: iconFrame.right }
                    text: application.entry ? application.entry.name : application.app
                        ? application.app.appId || (application.app.windows[0] ? application.app.windows[0].title : "") : ""
                    color: theme.foregroundColor
                    font { family: theme.fontFamily; pixelSize: theme.bodySize }
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                MouseArea { anchors.fill: parent; onClicked: switcher.candidateClicked(application.index) }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) {
                    if (!apps.interactive) return
                    apps.contentX = Math.max(apps.originX, Math.min(apps.originX + apps.contentWidth - apps.width,
                        apps.contentX - (wheel.angleDelta.x || wheel.angleDelta.y) / 2))
                    wheel.accepted = true
                }
            }
        }
        PlainText {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
            visible: switcher.candidates.length === 0
            text: switcher.emptyText
            color: theme.foregroundColor
            font { family: theme.fontFamily; pixelSize: theme.bodySize }
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
        }
        Rectangle {
            anchors { bottom: parent.bottom; bottomMargin: 3; horizontalCenter: parent.horizontalCenter }
            visible: apps.interactive
            width: 48; height: 2; radius: 1
            color: theme.borderColor
            Rectangle {
                width: Math.max(8, parent.width * Math.min(1, apps.width / apps.contentWidth))
                height: parent.height; radius: 1
                x: (parent.width - width) * Math.max(0, Math.min(1, (apps.contentX - apps.originX) / Math.max(1, apps.contentWidth - apps.width)))
                color: theme.foregroundColor
                opacity: 0.65
            }
        }
    }

    Item {
        id: bubble
        anchors { top: strip.bottom; topMargin: 16; left: parent.left; right: parent.right }
        height: 240
        visible: switcher.windowsExpanded
        Shape {
            id: outline
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real corner: Math.max(0, Math.min(theme.cornerRadius + 6, width / 2 - 0.5, height / 2 - 0.5))
            readonly property real tipSize: 8 * Math.SQRT2
            readonly property var selectedItem: apps.itemAtIndex(switcher.selectedIndex)
            readonly property real tipX: Math.max(corner + tipSize + 0.5, Math.min(width - corner - tipSize - 0.5,
                strip.x + 16 + (selectedItem ? selectedItem.x - apps.contentX + selectedItem.width / 2 : apps.width / 2)))
            // One filled outline keeps the pointer join seamless, including with translucent themes.
            ShapePath {
                strokeWidth: 1
                strokeColor: theme.borderColor
                fillColor: theme.backgroundColor
                startX: outline.corner + 0.5
                startY: 0.5
                PathLine { x: outline.tipX - outline.tipSize; y: 0.5 }
                PathLine { x: outline.tipX; y: 0.5 - outline.tipSize }
                PathLine { x: outline.tipX + outline.tipSize; y: 0.5 }
                PathLine { x: outline.width - outline.corner - 0.5; y: 0.5 }
                PathArc {
                    x: outline.width - 0.5; y: outline.corner + 0.5
                    radiusX: outline.corner; radiusY: outline.corner
                }
                PathLine { x: outline.width - 0.5; y: outline.height - outline.corner - 0.5 }
                PathArc {
                    x: outline.width - outline.corner - 0.5; y: outline.height - 0.5
                    radiusX: outline.corner; radiusY: outline.corner
                }
                PathLine { x: outline.corner + 0.5; y: outline.height - 0.5 }
                PathArc {
                    x: 0.5; y: outline.height - outline.corner - 0.5
                    radiusX: outline.corner; radiusY: outline.corner
                }
                PathLine { x: 0.5; y: outline.corner + 0.5 }
                PathArc {
                    x: outline.corner + 0.5; y: 0.5
                    radiusX: outline.corner; radiusY: outline.corner
                }
            }
        }
        ListView {
            id: windows
            objectName: "applicationWindowList"
            anchors { fill: parent; margins: 16 }
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentWidth > width
            model: switcher.windowKeys
            delegate: WindowPreviewCard {
                id: windowCard
                required property string modelData
                required property int index
                width: Math.min(276, windows.width)
                height: windows.height
                windowRecord: switcher.windowCandidates.find(function(window) { return window.key === windowCard.modelData }) || null
                previewProvider: switcher.previewProvider
                selected: index === switcher.selectedWindowIndex
                previewEnabled: switcher.visible && switcher.windowsExpanded
                    && x + width > windows.contentX && x < windows.contentX + windows.width
                onClicked: switcher.windowClicked(index)
            }
        }
    }
}
