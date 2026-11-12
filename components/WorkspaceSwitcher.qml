pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons as Commons
import "../generated/Logic.mjs" as Logic

Item {
    id: switcher
    required property string emptyText
    required property color foregroundColor
    required property var previewProvider
    property var candidates: []
    property var snapshot: ({windows: [], monitors: []})
    property int selectedIndex: -1
    property bool showMonitorLabels: true
    readonly property int spacing: 16
    // qmllint disable missing-property
    readonly property var layout: Logic.workspaceGrid(candidates.length)
    // qmllint enable missing-property
    readonly property int columns: layout.columns
    readonly property int rows: layout.rows
    readonly property real preferredWidth: columns * 480 + (columns - 1) * spacing
    readonly property real previewAspectRatio: {
        const monitor = snapshot.monitors.find(function(m) { return m.key === switcher.snapshot.sourceMonitorKey }) || snapshot.monitors[0]
        return monitor && monitor.geometry.width > 0 && monitor.geometry.height > 0 ? monitor.geometry.width / monitor.geometry.height : 16 / 9
    }
    implicitHeight: candidates.length > 0 ? rows * grid.cellHeight - spacing : 120
    signal candidateClicked(int index)
    onSelectedIndexChanged: { if (selectedIndex >= 0) grid.positionViewAtIndex(selectedIndex, GridView.Contain) }
    onCandidatesChanged: Qt.callLater(function() { grid.contentY = 0; if (switcher.selectedIndex >= 0) grid.positionViewAtIndex(switcher.selectedIndex, GridView.Contain) })
    onHeightChanged: Qt.callLater(function() { if (switcher.selectedIndex >= 0) grid.positionViewAtIndex(switcher.selectedIndex, GridView.Contain) })
    onWidthChanged: Qt.callLater(function() { if (switcher.selectedIndex >= 0) grid.positionViewAtIndex(switcher.selectedIndex, GridView.Contain) })
    GridView {
        id: grid
        anchors { fill: parent; rightMargin: -switcher.spacing }
        clip: true
        cacheBuffer: 0
        cellWidth: width / switcher.columns
        cellHeight: Math.max(100, (cellWidth - switcher.spacing) / switcher.previewAspectRatio) + switcher.spacing
        model: switcher.candidates
        delegate: WorkspacePreviewCard {
            required property var modelData
            required property int index
            width: grid.cellWidth - switcher.spacing
            height: grid.cellHeight - switcher.spacing
            label: (modelData.localSlot ? Commons.I18n.formatNumber(modelData.localSlot) : modelData.name)
                + (switcher.showMonitorLabels && switcher.snapshot.monitors.length > 1 ? " · " + modelData.monitorKey : "")
            selected: index === switcher.selectedIndex
            previewProvider: switcher.previewProvider
            previewEnabled: switcher.visible && y + height > grid.contentY && y < grid.contentY + grid.height
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
