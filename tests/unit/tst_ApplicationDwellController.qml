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
        wait(500)
        compare(expansion.count, 0)
        tryCompare(expansion, "count", 1, 400)
        compare(expansion.signalArguments[0][0], "application:first")
        wait(800)
        compare(expansion.count, 1)
    }
    function test_changingApplicationsRestartsDwell(): void {
        dwell.enabled = true
        wait(450)
        dwell.applicationKey = "application:second"
        wait(450)
        compare(expansion.count, 0)
        tryCompare(expansion, "count", 1, 500)
        compare(expansion.signalArguments[0][0], "application:second")
    }
    function test_metadataRefreshDoesNotRestartDwell(): void {
        dwell.enabled = true
        wait(450)
        dwell.windowCount = 3
        tryCompare(expansion, "count", 1, 400)
    }
    function test_disabledPanelDoesNotExpandLater(): void {
        dwell.enabled = true
        wait(450)
        dwell.enabled = false
        wait(800)
        compare(expansion.count, 0)
    }
    function test_singleWindowNeverAutoExpands(): void {
        dwell.windowCount = 1
        dwell.enabled = true
        wait(800)
        compare(expansion.count, 0)
        dwell.windowCount = 2
        tryCompare(expansion, "count", 1, 1000)
    }
}
