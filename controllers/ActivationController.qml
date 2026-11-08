import QtQuick

QtObject {
    readonly property bool available: false
    signal activationUnavailable(string reason)

    function activate(): bool {
        activationUnavailable("Activation is pending P0 focus validation")
        return false
    }

    // P0: release overlay input before dispatching and verify real focus events.
}
