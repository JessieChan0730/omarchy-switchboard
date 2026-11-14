import QtQuick
import QtTest
import "../../dist/plugin/controllers" as Controllers

TestCase {
    name: "SessionControllerDelivery"
    Controllers.SessionController { id: controller }
    SignalSpy { id: commits; target: controller; signalName: "commitRequested" }
    SignalSpy { id: cancellations; target: controller; signalName: "emptyConfirmed" }
    function test_refreshCancelsRemovedSelectionWithoutCommitting() {
        commits.clear()
        cancellations.clear()
        controller.begin({mode: "workspace", direction: 1}, {sourceMonitorKey: "left", originWorkspaceKey: "workspace:3"})
        controller.ready(["workspace:3", "workspace:21"], "workspace:3", false)
        controller.refresh(["workspace:3"])
        compare(controller.phase, "idle")
        compare(cancellations.count, 1)
        compare(commits.count, 0)
        controller.confirm()
        compare(commits.count, 0)
        controller.cancel()
    }
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
