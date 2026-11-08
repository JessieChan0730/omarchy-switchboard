import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui
import "controllers" as Controllers
import "adapters" as Adapters
import "previews" as Previews
import "components" as Components
import "generated/Logic.mjs" as Logic

Item {
    id: root

    property var shell: null
    property var manifest: null
    property bool opened: false
    property string mode: "window"

    function open(payloadJson: string): void {
        // ESM exports are checked by TypeScript and the Qt bridge tests.
        // qmllint disable missing-property
        root.mode = Logic.parseOpenRequest(payloadJson).mode
        // qmllint enable missing-property
        session.begin(payloadJson)
        root.opened = true
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    function close(): void {
        root.opened = false
        session.cancel()
        previews.stop()
    }

    function dismiss(): void {
        root.close()
        if (root.shell && typeof root.shell.hide === "function")
            root.shell.hide(root.manifest ? root.manifest.id : "jessie.switchboard")
    }

    Commons.Translations {
        id: strings
        directory: Qt.resolvedUrl("i18n")
    }

    Controllers.SessionController {
        id: session
        onSnapshotRequested: function(sessionId, mode) {
            adapter.requestSnapshot(sessionId)
        }
    }
    Controllers.ActivationController { id: activation }
    Adapters.HyprlandAdapter { id: adapter }
    Previews.PreviewProvider { id: previews }
    Components.Theme { id: theme }

    Ui.OverlayWindow {
        id: overlay
        shown: root.opened

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 640)
            height: Math.min(parent.height - 48, 240)
            radius: theme.cornerRadius
            color: theme.backgroundColor
            border.color: theme.borderColor
            border.width: 1

            Item {
                id: keyCatcher
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: function(event) {
                    root.dismiss()
                    event.accepted = true
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: theme.spacing

                    Components.PlainText {
                        width: parent.width
                        text: strings.t(root.mode === "workspace" ? "workspace.title" : "window.title")
                        color: theme.foregroundColor
                        font.family: theme.fontFamily
                        font.pixelSize: theme.titleSize
                    }

                    Components.WindowSwitcher {
                        width: parent.width
                        height: 80
                        visible: root.mode === "window"
                        emptyText: strings.t("status.prototype")
                        foregroundColor: theme.foregroundColor
                    }
                    Components.WorkspaceSwitcher {
                        width: parent.width
                        height: 80
                        visible: root.mode === "workspace"
                        emptyText: strings.t("status.prototype")
                        foregroundColor: theme.foregroundColor
                    }

                    Components.PlainText {
                        width: parent.width
                        text: strings.t("hint.dismiss")
                        color: theme.foregroundColor
                        font.family: theme.fontFamily
                        font.pixelSize: theme.bodySize
                    }
                }
            }
        }
    }

    Component.onDestruction: previews.stop()
}
