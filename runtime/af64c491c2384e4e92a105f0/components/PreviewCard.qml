pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../generated/Logic.mjs" as Logic

Rectangle {
    id: card
    required property string title
    property string subtitle: ""
    property string marker: ""
    property string appId: ""
    property bool selected: false
    property var windows: []
    property var viewport: ({x: 0, y: 0, width: 1, height: 1})
    property string emptyText: ""
    signal clicked()
    Theme { id: theme }
    implicitWidth: 224
    implicitHeight: 204
    radius: theme.cornerRadius
    color: theme.backgroundColor
    border.width: selected ? 2 : 1
    border.color: selected ? theme.accentColor : theme.borderColor

    Item {
        id: preview
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
        height: Math.max(40, parent.height - 70)
        clip: true
        Rectangle {
            anchors.fill: parent
            color: theme.foregroundColor
            opacity: 0.04
        }
        Repeater {
            model: card.windows
            Rectangle {
                id: miniature
                required property var modelData
                // qmllint disable missing-property
                readonly property var rect: Logic.fitGeometry(modelData.geometry, card.viewport, { width: preview.width, height: preview.height })
                // qmllint enable missing-property
                x: rect ? rect.x : 0
                y: rect ? rect.y : 0
                width: rect ? rect.width : 0
                height: rect ? rect.height : 0
                color: theme.backgroundColor
                border.color: theme.foregroundColor
                border.width: 1
                radius: Math.min(theme.cornerRadius, 4)
                clip: true
                PlainText {
                    anchors { fill: parent; margins: 4 }
                    text: miniature.modelData.appId || miniature.modelData.title
                    color: theme.foregroundColor
                    font.family: theme.fontFamily
                    font.pixelSize: Math.max(8, theme.bodySize - 2)
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        Image {
            id: appIcon
            anchors.centerIn: parent
            width: 44; height: 44
            visible: card.appId !== "" && status === Image.Ready
            source: {
                if (!card.appId) return ""
                const entry = DesktopEntries.heuristicLookup(card.appId)
                return Quickshell.iconPath(entry && entry.icon ? entry.icon : card.appId, true)
            }
            fillMode: Image.PreserveAspectFit
        }
        PlainText {
            anchors { fill: parent; margins: 8 }
            visible: card.windows.length === 0 && !appIcon.visible
            text: card.emptyText || card.appId
            color: theme.foregroundColor
            font.family: theme.fontFamily
            font.pixelSize: theme.bodySize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
        }
    }
    Column {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
        spacing: 4
        PlainText {
            width: parent.width
            text: (card.selected ? "› " : "") + card.title
            color: card.selected ? theme.accentColor : theme.foregroundColor
            font.family: theme.fontFamily
            font.pixelSize: theme.bodySize
            elide: Text.ElideRight
        }
        PlainText {
            width: parent.width
            text: card.subtitle + (card.marker ? " · " + card.marker : "")
            color: theme.foregroundColor
            opacity: 0.7
            font.family: theme.fontFamily
            font.pixelSize: Math.max(8, theme.bodySize - 2)
            elide: Text.ElideRight
        }
    }
    MouseArea { anchors.fill: parent; onClicked: card.clicked() }
}
