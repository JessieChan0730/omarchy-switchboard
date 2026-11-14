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
    function test_workspacePriorityIncludesBarSlots() {
        const queue = Logic.workspaceCandidates(desktop(false), ["workspace:3", "workspace:1", "workspace:5"])
        compare(keys(queue), ["workspace:3", "workspace:1", "workspace:5", "workspace:2", "workspace:4"])
        compare(queue.find(function(w) { return w.id === 2 }).canCreate, true)
        compare(queue.find(function(w) { return w.id === 4 }).exists, false)
        compare(queue.filter(function(w) { return w.id > 10 }).length, 0)
        compare(desktop(false).workspaces.length, 3)
    }
    function test_existingEmptyWorkspaceIsSelectable() {
        const snap = desktop(false)
        snap.workspaces.push({key: "workspace:2", id: 2, name: "2", monitorKey: "left", localSlot: 2, windowKeys: [], exists: true, isSpecial: false})
        const queue = Logic.workspaceCandidates(snap, ["workspace:3", "workspace:2", "workspace:1"])
        compare(keys(queue), ["workspace:3", "workspace:2", "workspace:1", "workspace:4", "workspace:5"])
        compare(queue.find(function(w) { return w.id === 2 }).exists, true)
        compare(queue.filter(function(w) { return w.id === 2 }).length, 1)
        compare(snap.workspaces.length, 4)
    }
    function test_barAddsOnlyExistingExtraSlots_data() {
        return [{tag: "six", extra: 6}, {tag: "gap-seven", extra: 7}, {tag: "gap-ten", extra: 10}]
    }
    function test_barAddsOnlyExistingExtraSlots(data) {
        const snap = desktop(false)
        const id = data.extra
        snap.workspaces.push({key: "workspace:" + id, id: id, name: String(id), monitorKey: "left", localSlot: id, windowKeys: [], exists: true, isSpecial: false})
        const before = JSON.stringify(snap)
        const queue = Logic.workspaceCandidates(snap, [])
        compare(queue.length, 6)
        compare(queue.map(function(w) { return w.id }).sort(function(a, b) { return a - b }), [1, 2, 3, 4, 5, id])
        compare(queue.find(function(w) { return w.id === id }).windowKeys.length, 0)
        compare(JSON.stringify(snap), before)
    }
    function test_multiMonitorQueueStaysOnSourceMonitor() {
        const snap = desktop(true)
        snap.workspaces.push({key: "workspace:12", id: 12, name: "12", monitorKey: "right", localSlot: 2, windowKeys: [], exists: true, isSpecial: false})
        const queue = Logic.workspaceCandidates(snap, ["workspace:3", "workspace:12", "workspace:11", "workspace:5", "workspace:1"])
        compare(keys(queue), ["workspace:3", "workspace:5", "workspace:1", "workspace:2", "workspace:4"])
        verify(queue.every(function(w) { return w.monitorKey === "left" }))
        const state = Logic.resolveSession(Logic.prepareSession(1, {mode: "workspace", direction: 1}, {}), 1,
            keys(queue), snap.currentWorkspaceKey, false)
        let forward = state
        let backward = state
        for (let i = 0; i < queue.length * 2; i++) {
            verify(Logic.confirmSession(forward, 1).targetKey !== "workspace:12")
            verify(Logic.confirmSession(backward, 1).targetKey !== "workspace:11")
            forward = Logic.stepSession(forward, 1, 1)
            backward = Logic.stepSession(backward, 1, -1)
        }
    }
    function test_secondMonitorUsesItsOwnSlotsAndHistory() {
        const snap = desktop(true)
        snap.sourceMonitorKey = "right"
        snap.currentWorkspaceKey = "workspace:11"
        snap.workspaces.push({key: "workspace:12", id: 12, name: "12", monitorKey: "right", localSlot: 2, windowKeys: [], exists: true, isSpecial: false})
        const queue = Logic.workspaceCandidates(snap, ["workspace:11", "workspace:3", "workspace:12", "workspace:5"])
        compare(keys(queue), ["workspace:11", "workspace:12", "workspace:13", "workspace:14", "workspace:15"])
        verify(queue.every(function(w) { return w.monitorKey === "right" }))
        compare(Logic.initialSelection(queue, "workspace:11", 1), 1)
        compare(Logic.initialSelection(queue, "workspace:11", -1), 4)
    }
    function test_workspaceActivationRejectsMovedOrDisconnectedTarget() {
        const snap = desktop(true)
        compare(Logic.workspaceActivationTarget(snap, "workspace:3", "left", 10).id, 3)
        compare(Logic.workspaceActivationTarget(snap, "workspace:13", "right", 10).canCreate, true)
        compare(Logic.workspaceActivationTarget(snap, "workspace:11", "left", 10), null)
        snap.workspaces.find(function(w) { return w.id === 3 }).monitorKey = "right"
        compare(Logic.workspaceActivationTarget(snap, "workspace:3", "left", 10), null)
        snap.monitors = snap.monitors.filter(function(m) { return m.key !== "right" })
        compare(Logic.workspaceActivationTarget(snap, "workspace:11", "right", 10), null)
    }
    function test_guestWorkspaceKeepsActualMonitorAndIsNotDuplicated() {
        const snap = desktop(true)
        snap.workspaces.find(function(w) { return w.id === 1 }).monitorKey = "right"
        snap.workspaces.push({key: "workspace:21", id: 21, name: "21", monitorKey: "left", localSlot: 1, windowKeys: [], exists: true, isSpecial: false})
        const queue = Logic.workspaceCandidates(snap, [])
        compare(queue.length, 5)
        compare(queue.filter(function(w) { return w.id === 1 }).length, 0)
        compare(queue.find(function(w) { return w.id === 21 }).monitorKey, "left")
        snap.sourceMonitorKey = "right"
        const rightQueue = Logic.workspaceCandidates(snap, [])
        compare(rightQueue.length, 6)
        compare(rightQueue.filter(function(w) { return w.id === 1 }).length, 1)
        compare(rightQueue.find(function(w) { return w.id === 1 }).monitorKey, "right")
        verify(!rightQueue.some(function(w) { return w.id === 21 }))
    }
    function test_emptyCurrentIsSelectionAnchor() {
        const snap = desktop(false)
        snap.currentWorkspaceKey = "workspace:5"
        snap.windows = snap.windows.filter(function(w) { return w.workspaceKey !== "workspace:5" })
        snap.workspaces.find(function(w) { return w.key === "workspace:5" }).windowKeys = []
        const queue = Logic.workspaceCandidates(snap, ["workspace:5", "workspace:1"])
        compare(keys(queue), ["workspace:5", "workspace:1", "workspace:2", "workspace:3", "workspace:4"])
        compare(Logic.initialSelection(queue, snap.currentWorkspaceKey, 1), 1)
        compare(Logic.initialSelection(queue, snap.currentWorkspaceKey, -1), queue.length - 1)
    }
    function test_allEmptyStillHasSelectableBarSlots() {
        const snap = desktop(false)
        snap.windows = []
        snap.workspaces.forEach(function(w) { w.windowKeys = [] })
        const queue = Logic.workspaceCandidates(snap, [])
        compare(keys(queue), ["workspace:3", "workspace:1", "workspace:2", "workspace:4", "workspace:5"])
        compare(Logic.initialSelection(queue, "workspace:3", 1), 1)
        compare(Logic.initialSelection(queue, "workspace:3", -1), 4)
        const state = Logic.resolveSession(Logic.prepareSession(1, {mode: "workspace", direction: 1}, {}), 1, keys(queue), "workspace:3", false)
        compare(Logic.confirmSession(state, 1).targetKey, "workspace:1")
    }
    function test_singleOccupiedWorkspaceCyclesThroughEmptySlots() {
        const snap = desktop(false)
        snap.windows = snap.windows.filter(function(w) { return w.workspaceKey === "workspace:3" })
        snap.workspaces.forEach(function(w) { if (w.key !== "workspace:3") w.windowKeys = [] })
        const queue = Logic.workspaceCandidates(snap, ["workspace:1", "workspace:5"])
        compare(keys(queue), ["workspace:3", "workspace:1", "workspace:5", "workspace:2", "workspace:4"])
        compare(Logic.initialSelection(queue, "workspace:3", 1), 1)
        compare(Logic.initialSelection(queue, "workspace:3", -1), 4)
        compare(Logic.wrapIndex(queue.length - 1, 1, queue.length), 0)
        compare(Logic.wrapIndex(0, -1, queue.length), queue.length - 1)
    }
    function test_newWorkspaceEntryStaysOutOfCycle() {
        const snap = desktop(true)
        const create = Logic.newWorkspace(snap, "right", 10)
        compare(create.id, 12)
        compare(create.exists, false)
        const queue = Logic.workspaceCandidates(snap, [])
        verify(!keys(queue).includes("create"))
        verify(!keys(queue).includes("workspace:12"))
        verify(!keys(queue).includes("workspace:10"))
        verify(!keys(queue).includes("workspace:16"))
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
        snap.windows.push({key: "named-window", address: "0xab", monitorKey: "left", workspaceKey: "named"})
        snap.windows.push({key: "bad", address: "bad address", monitorKey: "left", workspaceKey: "workspace:1"})
        const clean = Logic.parseSnapshot(snap)
        verify(clean.workspaces.some(function(w) { return w.key === "named" && !w.isSpecial }))
        verify(!clean.windows.some(function(w) { return w.key === "bad" }))
        const queue = Logic.workspaceCandidates(clean, [])
        verify(!queue.some(function(w) { return w.key === "special" }))
        // The top bar exposes numbered workspaces, not named/special ones.
        verify(!queue.some(function(w) { return w.key === "named" }))
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
