import QtQuick

Rectangle {
    id: card

    required property string title
    property bool selected: false
    property color backgroundColor: theme.backgroundColor
    property color foregroundColor: theme.foregroundColor
    property color accentColor: theme.accentColor
    property int cornerRadius: theme.cornerRadius

    Theme { id: theme }

    implicitWidth: 240
    implicitHeight: 160
    color: card.backgroundColor
    radius: card.cornerRadius
    border.width: card.selected ? 2 : 1
    border.color: card.selected ? card.accentColor : card.foregroundColor

    PlainText {
        anchors.centerIn: parent
        width: parent.width - 24
        text: card.title
        color: card.foregroundColor
        font.family: theme.fontFamily
        font.pixelSize: theme.bodySize
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    // P0: add aspect-preserving preview content, icon and workspace labels.
}
