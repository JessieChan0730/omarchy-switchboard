import QtQuick
import QtTest
import "../../dist/plugin/generated/Logic.mjs" as Logic
import "../fixtures" as Fixtures

TestCase {
    name: "TypeScriptQmlBridge"

    Fixtures.FakeHyprlandAdapter { id: fixture }

    function test_cycleAcrossEnds(): void {
        compare(Logic.wrapIndex(0, -1, fixture.windowKeys.length), 1)
        compare(Logic.wrapIndex(1, 1, fixture.windowKeys.length), 0)
        compare(Logic.wrapIndex(0, 1, 0), -1)
    }

    function test_historyDeduplicatesAndSkipsClosedTargets(): void {
        const history = Logic.recordFocus(["window:a", "window:b"], "window:b")
        compare(history, ["window:b", "window:a"])
        compare(Logic.recordFocus(history, "window:b"), history)
        compare(Logic.previousObject(history, "window:b", ["window:b"]), null)
        compare(Logic.previousObject(history, "window:b", fixture.windowKeys), "window:a")
    }

    function test_staleSessionCannotCancelNewSession(): void {
        const state = Logic.prepareSession(2, { mode: "window", direction: 1 }, {
            sourceMonitorKey: "monitor:1",
            originWindowKey: "window:a",
            originWorkspaceKey: "workspace:1"
        })
        compare(Logic.cancelSession(state, 1).phase, "preparing")
        compare(Logic.cancelSession(state, 2).phase, "idle")
    }

    function test_untrustedConfigUsesValidatedValues(): void {
        const config = Logic.parseConfig({ cacheBudgetMiB: -1, debug: "yes", captureConcurrency: 3 })
        compare(config.cacheBudgetMiB, 128)
        compare(config.debug, false)
        compare(config.captureConcurrency, 3)
        compare(Logic.parseOpenRequest("invalid json").mode, "window")
        compare(Logic.parseOpenRequest('{"mode":"workspace","direction":-1}').direction, -1)
    }

    function test_logicalGeometryKeepsAspectRatio(): void {
        const geometry = Logic.fitGeometry(
            { x: -100, y: 0, width: 100, height: 50 },
            { x: -100, y: 0, width: 200, height: 100 },
            { width: 100, height: 100 }
        )
        compare(geometry.x, 0)
        compare(geometry.y, 25)
        compare(geometry.width, 50)
        compare(geometry.height, 25)
        compare(Logic.fitGeometry(
            { x: 0, y: 0, width: 0, height: 50 },
            { x: 0, y: 0, width: 200, height: 100 },
            { width: 100, height: 100 }
        ), null)
    }
}
