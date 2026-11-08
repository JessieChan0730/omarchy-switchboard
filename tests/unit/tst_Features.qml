import QtQuick
import QtTest
import "../../dist/plugin/generated/Logic.mjs" as Logic

TestCase {
    name: "SwitcherFeatures"
    function desktop(twoMonitors) {
        const monitors = [{key: "left", connector: "eDP", slotStart: 1, geometry: {x: -1600, y: 0, width: 1600, height: 900}, scale: 1.6, transform: 0}]
        if (twoMonitors) monitors.push({key: "right", connector: "HDMI", slotStart: 11, geometry: {x: 0, y: 0, width: 1920, height: 1080}, scale: 1, transform: 0})
        const workspaces = [1, 3, 5, 11].map(function(id) { return {key: "workspace:" + id, id: id, name: String(id), monitorKey: id > 10 ? "right" : "left", localSlot: id > 10 ? id - 10 : id, exists: true, canCreate: false, isSpecial: false} })
        const windows = [1, 3, 5, 11].map(function(id, i) { return {key: "window:" + id, address: "0x" + id, title: "Window " + id, appId: "app", workspaceKey: "workspace:" + id, monitorKey: id > 10 ? "right" : "left", geometry: {x: 0, y: 0, width: 100, height: 100}, focusHistoryID: i} })
        return Logic.parseSnapshot({monitors: monitors, workspaces: workspaces, windows: windows, currentWindowKey: "window:3", currentWorkspaceKey: "workspace:3", sourceMonitorKey: "left"})
    }
    function keys(list) { return list.map(function(c) { return c.key }) }
    function preparing(id) { return Logic.prepareSession(id, {mode: "window", direction: 1}, {sourceMonitorKey: "left", originWindowKey: "a", originWorkspaceKey: "workspace:1"}) }

    function test_windowScopeAndMru() {
        compare(keys(Logic.windowCandidates(desktop(false), ["window:5", "window:1"])), ["window:3"])
        compare(keys(Logic.windowCandidates(desktop(true), ["window:5", "window:1"])), ["window:3", "window:5", "window:1"])
    }
    function test_workspacePriorityAndLegalSlots() {
        const queue = Logic.workspaceCandidates(desktop(false), ["workspace:3", "workspace:1", "workspace:5"], 10)
        compare(keys(queue).slice(0, 4), ["workspace:3", "workspace:1", "workspace:5", "workspace:2"])
        compare(queue.length, 10)
        compare(queue.filter(function(w) { return w.id > 10 }).length, 0)
        compare(desktop(false).workspaces.length, 3)
    }
    function test_multiMonitorQueueIsUnified() {
        const queue = Logic.workspaceCandidates(desktop(true), ["workspace:3", "workspace:11", "workspace:5", "workspace:1"], 10)
        compare(keys(queue).slice(0, 4), ["workspace:3", "workspace:11", "workspace:5", "workspace:1"])
        compare(queue.length, 20)
    }
    function test_emptyCurrentDoesNotDisplaceOccupiedWorkspaces() {
        const snap = desktop(false)
        snap.currentWorkspaceKey = "workspace:2"
        const queue = Logic.workspaceCandidates(snap, ["workspace:2", "workspace:1"], 10)
        compare(queue[0].key, "workspace:1")
        compare(Logic.initialSelection(queue, "workspace:2", 1, true), 0)
        compare(Logic.initialSelection(queue, "workspace:2", -1, true), queue.length - 1)
    }
    function test_allEmptyUsesCurrentAnchor() {
        const snap = desktop(false)
        snap.windows = []
        snap.workspaces.forEach(function(w) { w.windowKeys = [] })
        const queue = Logic.workspaceCandidates(snap, [], 10)
        compare(queue[0].id, 1)
        compare(Logic.initialSelection(queue, "workspace:3", 1), 3)
        compare(Logic.initialSelection(queue, "workspace:3", -1), 1)
    }
    function test_newWorkspaceEntryStaysOutOfCycle() {
        const snap = desktop(true)
        const create = Logic.newWorkspace(snap, "right", 10)
        compare(create.id, 12)
        compare(create.exists, false)
        const queue = Logic.workspaceCandidates(snap, [], 10)
        verify(!keys(queue).includes("create"))
        compare(Logic.wrapIndex(queue.length - 1, 1, queue.length), 0)
    }
    function test_fullMonitorCannotCreateInNextBlock() {
        const snap = desktop(true)
        for (let id = 2; id <= 10; id++) {
            if (!snap.workspaces.some(function(w) { return w.id === id })) snap.workspaces.push({key: "workspace:" + id, id: id, monitorKey: "left", name: String(id), windowKeys: [], exists: true, isSpecial: false})
        }
        compare(Logic.newWorkspace(snap, "left", 10), null)
    }
    function test_releaseBeforeSnapshotCommitsExactlyOnce() {
        let state = preparing(7)
        state = Logic.stepSession(state, 7, 1)
        state = Logic.confirmSession(state, 7)
        compare(state.phase, "preparing")
        state = Logic.resolveSession(state, 7, ["a", "b", "c"], "a", false)
        compare(state.phase, "committing")
        compare(state.targetKey, "c")
        compare(Logic.confirmSession(state, 7), state)
        compare(Logic.stepSession(state, 7, 1), state)
    }
    function test_oldSnapshotAndReleaseCannotChangeNewSession() {
        const state = preparing(9)
        compare(Logic.resolveSession(state, 8, ["a", "b"], "a", false), state)
        compare(Logic.confirmSession(state, 8), state)
        compare(Logic.stepSession(state, 8, 1), state)
    }
    function test_emptyAndSingleCandidateCommit() {
        compare(Logic.resolveSession(Logic.confirmSession(preparing(1), 1), 1, [], "a", false).phase, "idle")
        const state = Logic.resolveSession(preparing(2), 2, ["a"], "a", false)
        compare(state.selectedIndex, 0)
        compare(Logic.confirmSession(state, 2).targetKey, "a")
    }
    function test_snapshotValidationAndNamedWorkspaces() {
        const snap = desktop(false)
        snap.workspaces.push({key: "special", id: -99, name: "special:scratchpad", monitorKey: "left", isSpecial: true})
        snap.workspaces.push({key: "named", id: -1000, name: "开发", monitorKey: "left", isSpecial: false})
        snap.windows.push({key: "bad", address: "bad address", monitorKey: "left", workspaceKey: "workspace:1"})
        const clean = Logic.parseSnapshot(snap)
        verify(clean.workspaces.some(function(w) { return w.key === "named" && !w.isSpecial }))
        verify(!clean.windows.some(function(w) { return w.key === "bad" }))
        verify(!Logic.workspaceCandidates(clean, [], 10).some(function(w) { return w.key === "special" }))
    }
    function test_twoObjectToggleAndClosedHistory() {
        let history = Logic.recordFocus(["a", "b", "c"], "b")
        compare(Logic.previousObject(history, "b", ["a", "b", "c"]), "a")
        history = Logic.recordFocus(history, "a")
        compare(Logic.previousObject(history, "a", ["a", "b", "c"]), "b")
        compare(Logic.previousObject(history, "a", ["a", "c"]), "c")
    }
    function test_luaStringsEscapeControlAndQuotes() {
        compare(Logic.luaString('a"b\\c\n'), '"a\\"b\\\\c\\010"')
        compare(Logic.luaString('工作区'), '"工作区"')
    }
}
