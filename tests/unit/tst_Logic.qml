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

    function test_historyDeduplicatesAndKeepsMostRecentFirst(): void {
        const history = Logic.recordFocus(["window:a", "window:b"], "window:b")
        compare(history, ["window:b", "window:a"])
        compare(Logic.recordFocus(history, "window:b"), history)
        compare(Logic.recordFocus(history, "window:c", 2), ["window:c", "window:b"])
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

    function test_workspaceGrid_data() {
        return [
            {tag: "empty", count: 0, rows: 1, columns: 1},
            {tag: "single", count: 1, rows: 1, columns: 1},
            {tag: "two", count: 2, rows: 1, columns: 2},
            {tag: "four", count: 4, rows: 2, columns: 2},
            {tag: "five", count: 5, rows: 2, columns: 3},
            {tag: "six", count: 6, rows: 2, columns: 3},
            {tag: "eight", count: 8, rows: 2, columns: 4},
            {tag: "nine", count: 9, rows: 3, columns: 3},
            {tag: "ten", count: 10, rows: 3, columns: 4},
            {tag: "twelve", count: 12, rows: 3, columns: 4},
            {tag: "thirteen", count: 13, rows: 4, columns: 4},
            {tag: "sixteen", count: 16, rows: 4, columns: 4},
            {tag: "seventeen", count: 17, rows: 5, columns: 4},
            {tag: "many", count: 40, rows: 10, columns: 4}
        ]
    }
    function test_workspaceGrid(data): void {
        const grid = Logic.workspaceGrid(data.count)
        compare(grid.rows, data.rows)
        compare(grid.columns, data.columns)
        verify(grid.rows * grid.columns >= data.count)
    }
}
