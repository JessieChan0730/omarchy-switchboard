import QtQuick
import "../generated/Logic.mjs" as Logic

QtObject {
    id: controller
    // qmllint disable missing-property
    property var state: Logic.createIdleSession()
    readonly property string phase: state.phase
    readonly property int selectedIndex: state.phase === "selecting" ? state.selectedIndex : -1
    property int deliveredSessionId: -1
    signal commitRequested(string key)
    signal emptyConfirmed()

    function begin(request: var, context: var): void {
        state = Logic.prepareSession(state.sessionId + 1, request, context)
    }
    function ready(keys: var, current: var, occupiedFirst: bool): void {
        state = Logic.resolveSession(state, state.sessionId, keys, current, occupiedFirst)
        deliver()
    }
    function step(direction: int): void { state = Logic.stepSession(state, state.sessionId, direction) }
    function select(index: int): void { state = Logic.selectSession(state, index) }
    function confirm(): void {
        state = Logic.confirmSession(state, state.sessionId)
        deliver()
    }
    function deliver(): void {
        if (phase === "committing" && deliveredSessionId !== state.sessionId) {
            deliveredSessionId = state.sessionId
            commitRequested(state.targetKey)
        }
        else if (phase === "idle") emptyConfirmed()
    }
    function cancel(): void { state = Logic.cancelSession(state, state.sessionId) }
    // qmllint enable missing-property
}
