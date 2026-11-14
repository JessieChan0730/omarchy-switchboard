pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Commons as Commons
import "plugin/components" as Components

// Run through scripts/check.ts so qs.Commons and qs.Ui use the installed shell.
ShellRoot {
    id: test
    readonly property var cases: [
        {name: "six", count: 6, width: 1600, height: 900, aspect: 16 / 9},
        {name: "eight", count: 8, width: 1600, height: 900, aspect: 16 / 9},
        {name: "nine-fractional-scale", count: 9, width: 1600, height: 900, aspect: 16 / 9},
        {name: "ten-second-monitor", count: 10, width: 1600, height: 900, aspect: 16 / 9, base: 10},
        {name: "twelve-with-guests", count: 12, width: 1600, height: 900, aspect: 16 / 9, guestBase: 20},
        {name: "nine-small-screen", count: 9, width: 1280, height: 720, aspect: 16 / 9},
        {name: "nine-portrait-previews", count: 9, width: 1600, height: 900, aspect: 9 / 16},
        {name: "nine-ultrawide-previews", count: 9, width: 1600, height: 900, aspect: 21 / 9},
        {name: "minimum-card-scroll", count: 9, width: 640, height: 240, aspect: 16 / 9, scroll: true}
    ]
    property int caseIndex: 0
    readonly property var scenario: cases[caseIndex]
    property int cursor: 0
    property bool selecting: true
    property bool returning: false

    QtObject {
        id: provider
        readonly property string backgroundPath: ""
        function sourceForWindow(key: string): var { return null }
    }
    Item {
        width: test.scenario.width
        height: test.scenario.height
        Rectangle {
            id: panel
            width: Math.min(parent.width - 48, switcher.preferredWidth + 40)
            height: Math.min(parent.height - 64, switcher.implicitHeight + 40)
            Components.WorkspaceSwitcher {
                id: switcher
                anchors { fill: parent; margins: 20 }
                maximumHeight: Math.max(0, test.scenario.height - 64 - 40)
                emptyText: "Empty"
                foregroundColor: "white"
                previewProvider: provider
                showMonitorLabels: false
                candidates: Array.from({length: test.scenario.count}, function(_, index) {
                    const id = test.scenario.guestBase && index >= 10 ? test.scenario.guestBase + index - 9
                        : (test.scenario.base || 0) + index + 1
                    return {key: "workspace:" + id, id: id, name: String(id), localSlot: index % 10 + 1, monitorKey: "monitor"}
                })
                snapshot: ({windows: [], sourceMonitorKey: "monitor", monitors: [
                    {key: "monitor", geometry: {x: 0, y: 0, width: test.scenario.aspect * 900, height: 900}}
                ]})
            }
        }
    }
    Components.WindowSwitcher {
        id: windowSwitcher
        width: 1000
        height: 570
        emptyText: "Empty"
        foregroundColor: "white"
        showMonitorLabels: false
        candidates: [{key: "window:test", title: "Test", appId: "", workspaceKey: "workspace:20", monitorKey: "monitor"}]
        snapshot: ({monitors: [], workspaces: [{key: "workspace:20", localSlot: 10, name: "20"}]})
    }

    function check(condition: bool, message: string): bool {
        if (condition) return true
        console.error("FAIL: " + test.scenario.name + ": " + message)
        Qt.exit(1)
        return false
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            const grid = switcher.children[0] as GridView
            if (test.selecting) {
                switcher.selectedIndex = test.cursor
                grid.forceLayout()
                test.selecting = false
                return
            }
            const card = grid.itemAtIndex(test.cursor)
            if (!test.check(!!card, "selected card is instantiated")) return
            const slot = switcher.candidates[test.cursor].localSlot
            if (!test.check(card.label === Commons.I18n.formatNumber(slot === 10 ? 0 : slot), "label matches bar numbering")) return
            if (!test.check(card.y >= grid.contentY - 1 && card.y + card.height <= grid.contentY + grid.height + 1,
                "selected card is fully visible at index " + test.cursor)) return
            if (test.scenario.scroll) {
                if (!test.check(grid.interactive, "minimum size permits scrolling")) return
                if (test.cursor === test.scenario.count - 1) {
                    if (!test.check(grid.contentY > 0, "last row scrolls into view")) return
                    test.cursor = 0
                    test.returning = true
                    test.selecting = true
                    return
                }
                if (test.returning && !test.check(Math.abs(grid.contentY) < 0.01, "first row returns to origin")) return
            } else {
                if (!test.check(Math.abs(grid.contentY) < 0.01 && !grid.interactive,
                    "fitted grid stays fixed at index " + test.cursor + ", offset " + grid.contentY)) return
                if (!test.check(panel.width <= test.scenario.width - 48 && panel.height <= test.scenario.height - 64,
                    "panel stays within screen clearance")) return
            }
            if (!test.returning && ++test.cursor < test.scenario.count) {
                test.selecting = true
                return
            }
            if (!test.returning) {
                test.cursor = 0
                test.returning = true
                test.selecting = true
                return
            }
            console.log("PASS: " + test.scenario.name)
            if (test.caseIndex + 1 < test.cases.length) {
                test.caseIndex++
                test.cursor = 0
                test.returning = false
                test.selecting = true
                return
            }
            const windowGrid = windowSwitcher.children[0] as GridView
            if (!test.check(windowGrid.itemAtIndex(0).subtitle === Commons.I18n.formatNumber(0), "window subtitle uses slot zero")) return
            console.log("PASS: workspace labels and window subtitle use 0 for slot 10")
            Qt.quit()
        }
    }
    Timer { interval: 30000; running: true; onTriggered: { console.error("FAIL: layout test timed out"); Qt.exit(1) } }
}
