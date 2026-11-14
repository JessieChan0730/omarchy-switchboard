pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons as Commons

Item {
    id: switcher
    required property string emptyText
    required property color foregroundColor
    property var candidates: []
    property var snapshot: ({workspaces: [], monitors: []})
    property int selectedIndex: -1
    property bool showWorkspaceLabels: true
    property bool showMonitorLabels: true
    readonly property int columns: Math.max(1, Math.floor(width / 230))
    signal candidateClicked(int index)
    function reveal(): void { if (selectedIndex >= 0) grid.positionViewAtIndex(selectedIndex, GridView.Contain) }
    onSelectedIndexChanged: reveal()
    onCandidatesChanged: Qt.callLater(function() { grid.contentY = 0; switcher.reveal() })
    onHeightChanged: Qt.callLater(function() { switcher.reveal() })
    onWidthChanged: Qt.callLater(function() { switcher.reveal() })
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
            title: modelData.title || modelData.appId
            appId: modelData.appId
            subtitle: {
                const workspace = switcher.snapshot.workspaces.find(function(w) { return w.key === modelData.workspaceKey })
                const labels = []
                if (switcher.showWorkspaceLabels && workspace) labels.push(workspace.localSlot
                    ? Commons.I18n.formatNumber(workspace.localSlot === 10 ? 0 : workspace.localSlot) : workspace.name)
                if (switcher.showMonitorLabels) labels.push(modelData.monitorKey)
                return labels.join(" · ")
            }
            selected: index === switcher.selectedIndex
            onClicked: switcher.candidateClicked(index)
        }
    }
    PlainText {
        anchors.centerIn: parent
        width: parent.width
        visible: switcher.candidates.length === 0
        text: switcher.emptyText
        color: switcher.foregroundColor
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
}
