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
    property bool showMonitorLabels: true
    readonly property int columns: Math.max(1, Math.floor(width / 230))
    implicitHeight: Math.max(1, Math.ceil(candidates.length / columns)) * grid.cellHeight
    signal candidateClicked(int index)
    Commons.Translations { id: strings; directory: Qt.resolvedUrl("../i18n") }
    onSelectedIndexChanged: { if (selectedIndex >= 0) grid.positionViewAtIndex(selectedIndex, GridView.Contain) }
    onCandidatesChanged: Qt.callLater(function() { grid.contentY = 0; if (switcher.selectedIndex >= 0) grid.positionViewAtIndex(switcher.selectedIndex, GridView.Contain) })
    onHeightChanged: Qt.callLater(function() { if (switcher.selectedIndex >= 0) grid.positionViewAtIndex(switcher.selectedIndex, GridView.Contain) })
    onWidthChanged: Qt.callLater(function() { if (switcher.selectedIndex >= 0) grid.positionViewAtIndex(switcher.selectedIndex, GridView.Contain) })
    GridView {
        id: grid
        anchors.fill: parent
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
            selected: index === switcher.selectedIndex
            emptyText: strings.t("workspace.empty")
            windows: switcher.snapshot.windows.filter(function(w) { return w.workspaceKey === modelData.key })
            viewport: {
                const monitor = switcher.snapshot.monitors.find(function(m) { return m.key === modelData.monitorKey })
                return monitor ? monitor.geometry : {x: 0, y: 0, width: 1, height: 1}
            }
            onClicked: switcher.candidateClicked(index)
        }
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
