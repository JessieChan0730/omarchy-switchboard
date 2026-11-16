import QtQuick
import QtTest
import "../../dist/plugin/controllers" as Controllers

TestCase {
    name: "ApplicationDwellController"
    Controllers.ApplicationDwellController { id: dwell }
    SignalSpy { id: expansion; target: dwell; signalName: "expandRequested" }

    function init(): void {
        dwell.enabled = false
        dwell.applicationKey = "application:first"
        dwell.windowCount = 2
        expansion.clear()
    }
    function cleanup(): void { dwell.enabled = false }

    function test_waitsThenExpandsOnce(): void {
        dwell.enabled = true
        wait(180)
        compare(expansion.count, 0)
        tryCompare(expansion, "count", 1, 200)
        compare(expansion.signalArguments[0][0], "application:first")
        wait(280)
        compare(expansion.count, 1)
    }
    function test_changingApplicationsRestartsDwell(): void {
        dwell.enabled = true
        wait(160)
        dwell.applicationKey = "application:second"
        wait(160)
        compare(expansion.count, 0)
        tryCompare(expansion, "count", 1, 200)
        compare(expansion.signalArguments[0][0], "application:second")
    }
    function test_metadataRefreshDoesNotRestartDwell(): void {
        dwell.enabled = true
        wait(160)
        dwell.windowCount = 3
        tryCompare(expansion, "count", 1, 160)
    }
    function test_disabledPanelDoesNotExpandLater(): void {
        dwell.enabled = true
        wait(160)
        dwell.enabled = false
        wait(280)
        compare(expansion.count, 0)
    }
    function test_singleWindowNeverAutoExpands(): void {
        dwell.windowCount = 1
        dwell.enabled = true
        wait(280)
        compare(expansion.count, 0)
        dwell.windowCount = 2
        tryCompare(expansion, "count", 1, 400)
    }
}
