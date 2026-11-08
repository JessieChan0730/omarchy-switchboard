import QtQuick

Item {
    id: switcher
    required property string emptyText
    required property color foregroundColor

    PlainText {
        anchors.centerIn: parent
        width: parent.width
        text: switcher.emptyText
        color: switcher.foregroundColor
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    // P2: add workspace cards and a separate create-workspace entry.
}
