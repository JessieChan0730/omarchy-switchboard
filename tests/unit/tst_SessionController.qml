import QtQuick
import QtTest
import "../../dist/plugin/controllers" as Controllers

TestCase {
    name: "SessionControllerDelivery"
    Controllers.SessionController { id: controller }
    SignalSpy { id: commits; target: controller; signalName: "commitRequested" }
    function test_repeatedConfirmEmitsOncePerSession() {
        commits.clear()
        const context = {sourceMonitorKey: "left", originWindowKey: "a", originWorkspaceKey: "1"}
        controller.begin({mode: "window", direction: 1}, context)
        controller.ready(["a", "b"], "a", false)
        controller.confirm()
        controller.confirm()
        compare(commits.count, 1)
        compare(commits.signalArguments[0][0], "b")
        controller.cancel()
        controller.begin({mode: "window", direction: -1}, context)
        controller.confirm()
        controller.ready(["a", "b", "c"], "a", false)
        controller.confirm()
        compare(commits.count, 2)
        compare(commits.signalArguments[1][0], "c")
        controller.cancel()
    }
}
