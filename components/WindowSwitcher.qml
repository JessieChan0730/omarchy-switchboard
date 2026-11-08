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

    // P1: replace the prototype empty state with a virtualized window list.
}
