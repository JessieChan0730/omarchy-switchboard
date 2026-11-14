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
        {name: "twelve-with-guests", count: 12, width: 1600, height: 900, aspect: 16 / 9, base: 10, guestIds: [21, 30]},
        {name: "guests-before-third-monitor-block", count: 12, width: 1600, height: 900, aspect: 16 / 9, base: 20, guestIds: [1, 10]},
        {name: "guests-with-monitor-labels", count: 12, width: 1600, height: 900, aspect: 16 / 9, base: 10, guestIds: [21, 30], monitorLabels: true, secondMonitor: true},
        {name: "guests-after-disconnect", count: 12, width: 1600, height: 900, aspect: 16 / 9, guestIds: [11, 20], monitorLabels: true},
        {name: "thirteen-four-columns", count: 13, width: 1600, height: 900, aspect: 16 / 9, scroll: true},
        {name: "sixteen-four-columns", count: 16, width: 1600, height: 900, aspect: 16 / 9, scroll: true},
        {name: "seventeen-four-columns", count: 17, width: 1600, height: 900, aspect: 16 / 9, scroll: true},
        {name: "many-four-columns", count: 40, width: 1600, height: 900, aspect: 16 / 9, scroll: true},
        {name: "twelve-after-overflow", count: 12, width: 1600, height: 900, aspect: 16 / 9},
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
    property bool testingWindows: false
    property real twelveCardWidth: 0
    property real twelveCardHeight: 0
    property real twelvePanelHeight: 0

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
            height: Math.min(parent.height - 64, switcher.preferredHeight + 40)
            Components.WorkspaceSwitcher {
                id: switcher
                anchors { fill: parent; margins: 20 }
                maximumHeight: Math.max(0, test.scenario.height - 64 - 40)
                emptyText: "Empty"
                foregroundColor: "white"
                previewProvider: provider
                showMonitorLabels: test.scenario.monitorLabels === true
                candidates: Array.from({length: test.scenario.count}, function(_, index) {
                    const id = test.scenario.guestIds && index >= 10 ? test.scenario.guestIds[index - 10]
                        : (test.scenario.base || 0) + index + 1
                    return {key: "workspace:" + id, id: id, name: String(id), localSlot: (id - 1) % 10 + 1, monitorKey: "monitor"}
                })
                snapshot: ({windows: [], sourceMonitorKey: "monitor", monitors: [
                    {key: "monitor", slotStart: (test.scenario.base || 0) + 1, geometry: {x: 0, y: 0, width: test.scenario.aspect * 900, height: 900}}
                ].concat(test.scenario.secondMonitor ? [{key: "other", slotStart: 1}] : [])})
            }
        }
    }
    Components.WindowSwitcher {
        id: windowSwitcher
        width: 1600
        height: 570
        emptyText: "Empty"
        foregroundColor: "white"
        showMonitorLabels: false
        candidates: Array.from({length: 17}, function(_, index) {
            return {key: "window:" + index, title: "Test " + index, appId: "", workspaceKey: "workspace:20", monitorKey: "monitor"}
        })
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
            if (test.testingWindows) {
                const windowGrid = windowSwitcher.children[0] as GridView
                if (test.selecting) {
                    windowSwitcher.selectedIndex = test.returning ? 0 : windowSwitcher.candidates.length - 1
                    windowGrid.forceLayout()
                    test.selecting = false
                    return
                }
                if (!test.check(windowSwitcher.columns === 4, "large window grid has four columns")) return
                const card = windowGrid.itemAtIndex(windowSwitcher.selectedIndex)
                if (!test.check(!!card && card.y >= windowGrid.contentY - 1
                    && card.y + card.height <= windowGrid.contentY + windowGrid.height + 1, "selected window is fully visible")) return
                if (!test.returning) {
                    if (!test.check(windowGrid.interactive && windowGrid.contentY > 0, "large window grid scrolls to last row")) return
                    test.returning = true
                    test.selecting = true
                    return
                }
                if (!test.check(Math.abs(windowGrid.contentY) < 0.01, "window grid returns to first row")) return
                if (!test.check(card.subtitle === Commons.I18n.formatNumber(0), "window subtitle uses slot zero")) return
                console.log("PASS: large window grid keeps four columns, reveals selection and uses slot zero")
                Qt.quit()
                return
            }
            const grid = switcher.children[0] as GridView
            if (test.selecting) {
                switcher.selectedIndex = test.cursor
                grid.forceLayout()
                test.selecting = false
                return
            }
            const card = grid.itemAtIndex(test.cursor)
            if (!test.check(!!card, "selected card is instantiated")) return
            const candidate = switcher.candidates[test.cursor]
            const local = candidate.id > (test.scenario.base || 0) && candidate.id <= (test.scenario.base || 0) + 10
            const number = local ? candidate.localSlot === 10 ? 0 : candidate.localSlot : candidate.id
            const expectedBadge = (local ? "" : "↳ ") + Commons.I18n.formatNumber(number)
                + (test.scenario.monitorLabels && test.scenario.secondMonitor ? " · monitor" : "")
            if (!test.check(card.badgeText === expectedBadge, "badge identifies the current block or visiting global ID")) return
            if (!test.check(card.visiting === !local && (local ? card.tooltipText === "" : card.tooltipText !== ""),
                "guest marker and explanation persist with either monitor-label setting")) return
            const tooltip = Array.from(card.data).find(function(item) { return item.objectName === "workspaceTooltip" })
            if (!test.check(!!tooltip && tooltip.contentItem.textFormat === Text.PlainText, "tooltip renders plain text")) return
            if (!test.check(card.y >= grid.contentY - 1 && card.y + card.height <= grid.contentY + grid.height + 1,
                "selected card is fully visible at index " + test.cursor)) return
            if (test.scenario.count === 12 && test.cursor === 0 && !test.returning) {
                test.twelveCardWidth = card.width
                test.twelveCardHeight = card.height
                test.twelvePanelHeight = panel.height
            }
            if (test.scenario.count > 12) {
                if (!test.check(switcher.columns === 4, "large workspace grid has four columns")) return
                if (!test.check(Math.abs(card.width - test.twelveCardWidth) < 0.01
                    && Math.abs(card.height - test.twelveCardHeight) < 0.01
                    && Math.abs(panel.height - test.twelvePanelHeight) < 0.01, "overflow preserves twelve-item card and panel sizes")) return
                if (test.cursor < 12 && !test.returning
                    && !test.check(Math.abs(grid.contentY) < 0.01, "first twelve items remain visible without scrolling")) return
            }
            if (test.scenario.scroll) {
                if (!test.check(grid.interactive, "overflow permits scrolling")) return
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
            test.testingWindows = true
            test.returning = false
            test.selecting = true
        }
    }
    Timer { interval: 30000; running: true; onTriggered: { console.error("FAIL: layout test timed out"); Qt.exit(1) } }
}
