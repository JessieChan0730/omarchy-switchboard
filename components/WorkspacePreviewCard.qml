pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../generated/Logic.mjs" as Logic

Rectangle {
    id: card
    required property string label
    required property var previewProvider
    property bool selected: false
    property bool previewEnabled: false
    property var windows: []
    property var windowKeys: []
    property var viewport: ({x: 0, y: 0, width: 1, height: 1})
    signal clicked()

    // Keep capture delegates alive when only window positions or titles change.
    onWindowsChanged: {
        const keys = windows.map(function(window) { return window.key })
        if (JSON.stringify(keys) !== JSON.stringify(windowKeys)) windowKeys = keys
    }

    Theme { id: theme }
    radius: theme.cornerRadius
    color: theme.backgroundColor
    border.width: selected ? 3 : 1
    border.color: selected ? theme.accentColor : theme.borderColor

    Item {
        id: preview
        anchors { fill: parent; margins: 8 }
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: Math.max(0, theme.cornerRadius - 4)
            color: theme.foregroundColor
            opacity: 0.04
        }

        Repeater {
            model: card.windowKeys
            Rectangle {
                id: miniature
                required property string modelData
                readonly property var windowRecord: card.windows.find(function(window) { return window.key === miniature.modelData })
                readonly property var captureSource: card.previewProvider.sourceForWindow(modelData)
                property bool captureStopped: false
                // qmllint disable missing-property
                readonly property var rect: windowRecord ? Logic.fitGeometry(windowRecord.geometry, card.viewport, {width: preview.width, height: preview.height}) : null
                // qmllint enable missing-property
                readonly property ScreencopyView capture: captureLoader.item as ScreencopyView
                readonly property bool hasPreview: capture !== null && capture.hasContent
                onCaptureSourceChanged: captureStopped = false

                x: rect ? rect.x : 0
                y: rect ? rect.y : 0
                width: rect ? rect.width : 0
                height: rect ? rect.height : 0
                z: windowRecord && windowRecord.fullscreen ? 2 : windowRecord && windowRecord.floating ? 1 : 0
                color: theme.backgroundColor
                clip: true

                Loader {
                    id: captureLoader
                    anchors.fill: parent
                    active: card.previewEnabled && miniature.captureSource !== null && miniature.rect !== null && !miniature.captureStopped
                    sourceComponent: ScreencopyView {
                        anchors.centerIn: parent
                        captureSource: miniature.captureSource
                        live: true
                        paintCursor: false
                        constraintSize: Qt.size(miniature.width, miniature.height)
                        onStopped: miniature.captureStopped = true
                    }
                }

                Image {
                    id: appIcon
                    anchors.centerIn: parent
                    width: Math.min(48, parent.width * 0.35, parent.height * 0.35)
                    height: width
                    visible: !miniature.hasPreview && status === Image.Ready
                    source: {
                        const appId = miniature.windowRecord ? miniature.windowRecord.appId : ""
                        if (!appId) return ""
                        const entry = DesktopEntries.heuristicLookup(appId)
                        return Quickshell.iconPath(entry && entry.icon ? entry.icon : appId, true)
                    }
                    fillMode: Image.PreserveAspectFit
                }
                PlainText {
                    anchors { fill: parent; margins: 8 }
                    visible: !miniature.hasPreview && !appIcon.visible
                    text: miniature.windowRecord ? miniature.windowRecord.appId || miniature.windowRecord.title : ""
                    color: theme.foregroundColor
                    font.family: theme.fontFamily
                    font.pixelSize: theme.bodySize
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; margins: 14 }
        width: Math.min(card.width - 28, badge.implicitWidth + 20)
        height: badge.implicitHeight + 10
        radius: Math.min(theme.cornerRadius, 8)
        color: theme.backgroundColor
        border.width: 1
        border.color: card.selected ? theme.accentColor : theme.borderColor

        PlainText {
            id: badge
            anchors { fill: parent; leftMargin: 10; rightMargin: 10; topMargin: 5; bottomMargin: 5 }
            text: card.label
            color: card.selected ? theme.accentColor : theme.foregroundColor
            font.family: theme.fontFamily
            font.pixelSize: theme.bodySize
            font.bold: card.selected
            elide: Text.ElideRight
        }
    }
    MouseArea { anchors.fill: parent; onClicked: card.clicked() }
}
