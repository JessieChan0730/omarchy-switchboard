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
    property real maximumHeight: Infinity
    readonly property int spacing: 16
    // qmllint disable missing-property
    readonly property var layout: Logic.workspaceGrid(candidates.length)
    // qmllint enable missing-property
    readonly property int columns: layout.columns
    readonly property int rows: layout.rows
    readonly property real previewAspectRatio: {
        const monitor = snapshot.monitors.find(function(m) { return m.key === switcher.snapshot.sourceMonitorKey }) || snapshot.monitors[0]
        return monitor && monitor.geometry.width > 0 && monitor.geometry.height > 0 ? monitor.geometry.width / monitor.geometry.height : 16 / 9
    }
    // Fit every row within the screen before sizing the panel. Keep cards at
    // least 100px tall; larger overviews can still scroll at that minimum.
    readonly property real preferredCardHeight: Math.max(100, Math.min(480 / previewAspectRatio,
        (maximumHeight - (rows - 1) * spacing) / rows))
    readonly property real preferredWidth: columns * preferredCardHeight * previewAspectRatio + (columns - 1) * spacing
    implicitHeight: candidates.length > 0 ? rows * grid.cellHeight - spacing : 120
    signal candidateClicked(int index)

    function revealSelection(): void {
        if (selectedIndex < 0 || selectedIndex >= candidates.length || grid.height <= 0) return
        grid.cancelFlick()
        // GridView.Contain includes the trailing cell gap. Use the card's
        // actual bounds so selecting the last visible row never scrolls it.
        const maxOffset = Math.max(0, implicitHeight - grid.height)
        if (maxOffset <= 1) { grid.contentY = 0; return }
        const top = Math.floor(selectedIndex / columns) * grid.cellHeight
        const bottom = top + grid.cellHeight - spacing
        let offset = Math.max(0, Math.min(maxOffset, grid.contentY))
        if (top < offset - 1) offset = top
        else if (bottom > offset + grid.height + 1) offset = bottom - grid.height
        grid.contentY = Math.max(0, Math.min(maxOffset, offset))
    }
    onSelectedIndexChanged: Qt.callLater(revealSelection)
    onCandidatesChanged: Qt.callLater(function() { grid.contentY = 0; switcher.revealSelection() })
    onHeightChanged: Qt.callLater(revealSelection)
    onWidthChanged: Qt.callLater(revealSelection)
    GridView {
        id: grid
        anchors { fill: parent; rightMargin: -switcher.spacing }
        clip: true
        cacheBuffer: 0
        interactive: switcher.implicitHeight > height + 1
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: width / switcher.columns
        cellHeight: Math.max(100, (cellWidth - switcher.spacing) / switcher.previewAspectRatio) + switcher.spacing
        model: switcher.candidates
        delegate: WorkspacePreviewCard {
            required property var modelData
            required property int index
            width: grid.cellWidth - switcher.spacing
            height: grid.cellHeight - switcher.spacing
            label: (modelData.localSlot ? Commons.I18n.formatNumber(modelData.localSlot === 10 ? 0 : modelData.localSlot) : modelData.name)
                + (switcher.showMonitorLabels && switcher.snapshot.monitors.length > 1 ? " · " + modelData.monitorKey : "")
            selected: index === switcher.selectedIndex
            previewProvider: switcher.previewProvider
            backgroundPath: switcher.previewProvider.backgroundPath || ""
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
