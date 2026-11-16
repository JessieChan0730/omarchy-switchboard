pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../controllers" as Controllers

Rectangle {
    id: card
    required property var previewProvider
    property var windowRecord: null
    property bool selected: false
    property bool previewEnabled: false
    readonly property var captureSource: windowRecord ? previewProvider.sourceForWindow(windowRecord.key) : null
    readonly property ScreencopyView capture: captureLoader.item as ScreencopyView
    readonly property bool hasPreview: capture !== null && capture.hasContent
    readonly property bool presentationReady: readiness.ready
    readonly property bool fallbackVisible: readiness.fallbackReady && !hasPreview
    signal clicked()
    Theme { id: theme }
    color: theme.backgroundColor
    radius: Math.min(12, theme.cornerRadius)
    border { width: selected ? 2 : 1; color: selected ? theme.accentColor : theme.borderColor }
    Controllers.PreviewReadinessController {
        id: readiness
        active: card.previewEnabled
        sourceKey: card.windowRecord ? card.windowRecord.key : ""
        hasContent: card.hasPreview
    }
    Item {
        id: preview
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
        height: Math.max(1, card.height - 44)
        clip: true
        Rectangle { anchors.fill: parent; color: theme.foregroundColor; opacity: 0.04; radius: 6 }
        Controllers.CaptureRetryController {
            id: retry
            active: card.previewEnabled
            source: card.captureSource
            hasContent: card.hasPreview
        }
        Loader {
            id: captureLoader
            anchors.fill: parent
            active: retry.captureEnabled
            sourceComponent: ScreencopyView {
                anchors.centerIn: parent
                captureSource: card.captureSource
                live: true
                paintCursor: false
                constraintSize: Qt.size(preview.width, preview.height)
                onStopped: retry.captureFailed()
            }
        }
        Image {
            id: icon
            anchors.centerIn: parent
            width: 48; height: 48
            visible: card.fallbackVisible && status === Image.Ready
            source: {
                const appId = card.windowRecord ? card.windowRecord.appId : ""
                const entry = appId ? DesktopEntries.heuristicLookup(appId) : null
                return Quickshell.iconPath(entry && entry.icon ? entry.icon : "application-x-executable", true)
            }
            fillMode: Image.PreserveAspectFit
        }
    }
    PlainText {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
        text: card.windowRecord ? card.windowRecord.title || card.windowRecord.appId : ""
        color: card.selected ? theme.accentColor : theme.foregroundColor
        font { family: theme.fontFamily; pixelSize: theme.bodySize }
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
    MouseArea { anchors.fill: parent; onClicked: card.clicked() }
}
