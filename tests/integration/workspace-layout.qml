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
    property bool testingSingleApplication: false
    property int bubbleTestStage: 0
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
        width: 640
        height: preferredHeight
        emptyText: "Empty"
        foregroundColor: "white"
        previewProvider: provider
        windowsExpanded: true
        candidates: Array.from({length: 17}, function(_, index) {
            return {key: "application:" + index, appId: "", windows: [{key: "window:" + index, title: "<b>Test " + index + "</b>"}]}
        })
        windowCandidates: Array.from({length: 8}, function(_, index) {
            return {key: "window:" + index, title: "Test " + index, appId: ""}
        })
    }

    function check(condition: bool, message: string): bool {
        if (condition) return true
        console.error("FAIL: " + test.scenario.name + ": " + message)
        Qt.exit(1)
        return false
    }

    function checkIndicator(view: Item, scrolling: bool, edge: int): bool {
        const indicator = Array.from(view.children).find(function(item) { return item.objectName === "scrollPositionIndicator" })
        if (!check(!!indicator && indicator.visible === scrolling, "position hint appears only with overflow")) return false
        if (!scrolling) return true
        if (!check(indicator.width === 4 && indicator.thumbLength > 0 && indicator.thumbLength < indicator.height
            && indicator.thumbOffset >= 0 && indicator.thumbOffset + indicator.thumbLength <= indicator.height + 0.01,
            "thin position hint stays within its track")) return false
        return check(edge < 0 || Math.abs(indicator.position - edge) < 0.01, "position hint reaches the scroll edge")
    }

    function checkApplicationName(app: Item): bool {
        const name = app.children.find(function(child) { return child.objectName === "applicationName" })
        return check(!!name && name.visible && name.text === app.app.windows[0].title
            && name.textFormat === Text.PlainText && name.horizontalAlignment === Text.AlignHCenter
            && name.maximumLineCount === 1 && name.elide === Text.ElideRight
            && name.y >= 92 && Math.abs(name.x + name.width / 2 - app.width / 2) < 0.01
            && name.y + name.height <= app.height,
            "each application name is plain text, centered below its icon, and fits the row")
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (test.testingWindows) {
                const appList = windowSwitcher.children.find(function(child) { return child.children
                    && child.children.some(function(item) { return item.objectName === "applicationList" }) }).children.find(function(item) { return item.objectName === "applicationList" }) as ListView
                const windowList = windowSwitcher.children.find(function(child) { return child.children
                    && child.children.some(function(item) { return item.objectName === "applicationWindowList" }) }).children.find(function(item) { return item.objectName === "applicationWindowList" }) as ListView
                if (test.bubbleTestStage === 1) {
                    if (windowSwitcher.bubbleVisible) return
                    if (!test.check(windowSwitcher.preferredHeight === windowSwitcher.stripHeight,
                        "collapsing releases preview space after the exit transition")) return
                    windowSwitcher.candidates = [windowSwitcher.candidates[0]]
                    windowSwitcher.selectedIndex = 0
                    windowSwitcher.width = windowSwitcher.preferredWidth
                    test.testingSingleApplication = true
                    test.bubbleTestStage = 2
                    return
                }
                if (test.testingSingleApplication) {
                    appList.forceLayout()
                    const app = appList.itemAtIndex(0)
                    if (!test.check(!!app && !appList.interactive && Math.abs(windowSwitcher.applicationContentX) < 0.01,
                        "a single application stays visible without horizontal scrolling")) return
                    if (!test.checkApplicationName(app)) return
                    const name = app.children.find(function(child) { return child.objectName === "applicationName" })
                    if (!test.check(Math.abs(name.mapToItem(windowSwitcher, name.width / 2, 0).x - windowSwitcher.width / 2) < 0.01,
                        "a single application's icon and name are centered in the panel")) return
                    if (!windowSwitcher.windowsExpanded) {
                        windowSwitcher.windowsExpanded = true
                        windowSwitcher.width = windowSwitcher.preferredWidth
                        return
                    }
                    if (windowSwitcher.bubbleOpacity < 1) return
                    if (test.bubbleTestStage === 2) {
                        windowSwitcher.panelActive = false
                        windowSwitcher.panelActive = true
                        if (!test.check(windowSwitcher.bubbleOpacity === 0,
                            "reopening interrupts the old transition and starts with transparent previews")) return
                        test.bubbleTestStage = 3
                        return
                    }
                    const outline = windowList.parent.children.find(function(child) { return child.tipX !== undefined })
                    if (!test.check(!!outline && Math.abs(outline.tipX - outline.width / 2) < 0.01,
                        "the expanded single application's bubble points to the centered icon")) return
                    console.log("PASS: application names and centered single-application layout before and after expansion")
                    Qt.quit()
                    return
                }
                if (test.selecting) {
                    windowSwitcher.selectedIndex = test.returning ? 0 : windowSwitcher.candidates.length - 1
                    windowSwitcher.selectedWindowIndex = test.returning ? 0 : windowSwitcher.windowCandidates.length - 1
                    appList.forceLayout()
                    windowList.forceLayout()
                    test.selecting = false
                    return
                }
                const app = appList.itemAtIndex(windowSwitcher.selectedIndex)
                const card = windowList.itemAtIndex(windowSwitcher.selectedWindowIndex)
                if (!test.check(appList.orientation === ListView.Horizontal && appList.interactive,
                    "applications stay in a single scrolling row")) return
                if (!test.check(!!app && app.x >= appList.contentX - 1 && app.x + app.width <= appList.contentX + appList.width + 1,
                    "selected app is fully visible")) return
                if (!test.check(!!card && card.x >= windowList.contentX - 1 && card.x + card.width <= windowList.contentX + windowList.width + 1,
                    "selected window preview is fully visible")) return
                if (!test.check(app.y === 0 && card.y === 0, "neither row wraps")) return
                if (!test.checkApplicationName(app)) return
                const neighbour = appList.itemAtIndex(test.returning ? 1 : windowSwitcher.selectedIndex - 1)
                if (!test.check(!!neighbour && !neighbour.selected, "an unselected neighbouring application is present")) return
                if (!test.checkApplicationName(neighbour)) return
                if (!test.returning) {
                    if (!test.check(windowSwitcher.applicationContentX > 0 && windowSwitcher.windowContentX > 0, "both rows reveal their final selection")) return
                    test.returning = true
                    test.selecting = true
                    return
                }
                if (!test.check(Math.abs(windowSwitcher.applicationContentX) < 0.01 && Math.abs(windowSwitcher.windowContentX) < 0.01,
                    "both rows return to origin")) return
                windowSwitcher.windowsExpanded = false
                console.log("PASS: app and window rows scroll horizontally and reveal selected items")
                test.bubbleTestStage = 1
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
            if (!test.checkIndicator(switcher, !!test.scenario.scroll,
                test.cursor === 0 ? 0 : test.cursor === test.scenario.count - 1 ? 1 : -1)) return
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
