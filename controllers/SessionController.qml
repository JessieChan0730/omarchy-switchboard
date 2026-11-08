import QtQuick
import "../generated/Logic.mjs" as Logic

QtObject {
    id: controller

    // ESM export lists are resolved at runtime by the Qt bridge tests.
    // qmllint disable missing-property
    property var state: Logic.createIdleSession()
    // qmllint enable missing-property
    readonly property string phase: controller.state.phase

    signal snapshotRequested(int sessionId, string mode)

    function begin(payloadJson: string): void {
        // qmllint disable missing-property
        const request = Logic.parseOpenRequest(payloadJson)
        controller.state = Logic.prepareSession(controller.state.sessionId + 1, request, {
            sourceMonitorKey: null,
            originWindowKey: null,
            originWorkspaceKey: null
        })
        // qmllint enable missing-property
        controller.snapshotRequested(controller.state.sessionId, request.mode)
    }

    function cancel(): void {
        // qmllint disable missing-property
        controller.state = Logic.cancelSession(controller.state, controller.state.sessionId)
        // qmllint enable missing-property
    }

    // P0: connect snapshot readiness, modifier release and exactly-once commit.
}
