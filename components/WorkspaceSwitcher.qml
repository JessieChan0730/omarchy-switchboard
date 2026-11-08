pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons as Commons

Item {
    id: switcher
    required property string emptyText
    required property color foregroundColor
    property var candidates: []
    property var snapshot: ({windows: [], monitors: []})
    property int selectedIndex: -1
    property string currentKey: ""
    property string previousKey: ""
    property string sourceMonitor: ""
    property bool createSelected: false
    property bool canCreate: false
    property bool showMonitorLabels: true
    readonly property int columns: Math.max(1, Math.floor(width / 230))
    signal candidateClicked(int index)
    signal createClicked()
    Theme { id: theme }
    Commons.Translations { id: strings; directory: Qt.resolvedUrl("../i18n") }
    onSelectedIndexChanged: { if (selectedIndex >= 0) grid.positionViewAtIndex(selectedIndex, GridView.Contain) }
    onCandidatesChanged: Qt.callLater(function() { grid.contentY = 0; if (switcher.selectedIndex >= 0) grid.positionViewAtIndex(switcher.selectedIndex, GridView.Contain) })
    onHeightChanged: Qt.callLater(function() { if (switcher.selectedIndex >= 0) grid.positionViewAtIndex(switcher.selectedIndex, GridView.Contain) })
    onWidthChanged: Qt.callLater(function() { if (switcher.selectedIndex >= 0) grid.positionViewAtIndex(switcher.selectedIndex, GridView.Contain) })
    GridView {
        id: grid
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: create.top; bottomMargin: 12 }
        clip: true
        cellWidth: width / switcher.columns
        cellHeight: 210
        model: switcher.candidates
        delegate: PreviewCard {
            required property var modelData
            required property int index
            width: grid.cellWidth - 8
            height: grid.cellHeight - 8
            title: strings.t("workspace.label").arg(modelData.localSlot || modelData.name)
            subtitle: strings.tn("workspace.count", modelData.windowKeys.length).arg(modelData.windowKeys.length)
                + (switcher.showMonitorLabels ? " · " + modelData.monitorKey : "")
            marker: modelData.key === switcher.currentKey ? strings.t("workspace.current") : modelData.key === switcher.previousKey ? strings.t("workspace.previous") : ""
            selected: !switcher.createSelected && index === switcher.selectedIndex
            emptyText: strings.t("workspace.empty")
            windows: switcher.snapshot.windows.filter(function(w) { return w.workspaceKey === modelData.key })
            viewport: {
                const monitor = switcher.snapshot.monitors.find(function(m) { return m.key === modelData.monitorKey })
                return monitor ? monitor.geometry : {x: 0, y: 0, width: 1, height: 1}
            }
            onClicked: switcher.candidateClicked(index)
        }
    }
    Rectangle {
        id: create
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 38
        color: theme.backgroundColor
        radius: theme.cornerRadius
        border.color: switcher.createSelected ? theme.accentColor : theme.borderColor
        border.width: switcher.createSelected ? 2 : 1
        opacity: switcher.canCreate ? 1 : 0.5
        PlainText {
            anchors { fill: parent; margins: 8 }
            text: (switcher.canCreate ? strings.t("workspace.create") : strings.t("workspace.capacity")) + " · " + switcher.sourceMonitor
            color: theme.foregroundColor
            font.family: theme.fontFamily
            font.pixelSize: theme.bodySize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        MouseArea { anchors.fill: parent; enabled: switcher.canCreate; onClicked: switcher.createClicked() }
    }
    PlainText {
        anchors.centerIn: grid
        width: parent.width
        visible: switcher.candidates.length === 0
        text: switcher.emptyText
        color: switcher.foregroundColor
        horizontalAlignment: Text.AlignHCenter
    }
}
