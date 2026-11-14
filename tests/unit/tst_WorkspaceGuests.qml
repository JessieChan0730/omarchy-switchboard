import QtQuick
import QtTest
import "../../dist/plugin/generated/Logic.mjs" as Logic

TestCase {
    name: "WorkspaceGuests"

    function workspace(id, monitor) {
        return {key: "workspace:" + id, id: id, name: String(id), localSlot: (id - 1) % 10 + 1,
            monitorKey: monitor, homeMonitorKey: id > 20 ? "unplugged" : monitor, exists: true, isSpecial: false}
    }
    function desktop(full) {
        return Logic.parseSnapshot({
            monitors: [
                {key: "left", connector: "eDP", slotStart: 1},
                {key: "right", connector: "HDMI", slotStart: 11}
            ],
            workspaces: (full ? Array.from({length: 10}, function(_, i) { return workspace(i + 1, "left") })
                : [workspace(1, "left"), workspace(3, "left")]).concat([workspace(11, "right")]),
            sourceMonitorKey: "left", currentWorkspaceKey: "workspace:3"
        })
    }
    function keys(candidates) { return candidates.map(function(w) { return w.key }) }
    function selecting(candidates, key) {
        const state = Logic.resolveSession(Logic.prepareSession(9, {mode: "workspace", direction: 1},
            {sourceMonitorKey: "left", originWorkspaceKey: "workspace:3"}), 9, keys(candidates), "workspace:3", false)
        return Logic.selectSession(state, keys(candidates).indexOf(key))
    }

    function test_fullMonitorStillIncludesGuestsBeyondTen() {
        const snap = desktop(true)
        snap.workspaces.push(workspace(21, "left"), workspace(30, "left"))
        const queue = Logic.workspaceCandidates(snap, ["workspace:3", "workspace:30", "workspace:11"])
        compare(queue.length, 12)
        verify(queue.every(function(w) { return w.monitorKey === "left" }))
        compare(queue.find(function(w) { return w.id === 21 }).localSlot, 1)
        compare(queue.find(function(w) { return w.id === 30 }).localSlot, 10)
        compare(queue.find(function(w) { return w.id === 21 }).homeMonitorKey, "unplugged")
        for (const id of [21, 30]) {
            compare(Logic.workspaceActivationTarget(snap, "workspace:" + id, "left", 5).id, id)
            compare(Logic.confirmSession(selecting(queue, "workspace:" + id), 9).targetKey, "workspace:" + id)
        }
        compare(Logic.newWorkspace(snap, "left", 10), null)
    }
    function test_guestUsesActualScreenAndGlobalIdentity() {
        const snap = desktop(true)
        snap.workspaces.push(workspace(21, "left"), workspace(31, "left"), workspace(41, "right"))
        const queue = Logic.workspaceCandidates(snap, [])
        compare(queue.filter(function(w) { return w.localSlot === 1 }).length, 3)
        compare(queue.filter(function(w) { return w.id === 21 }).length, 1)
        compare(queue.filter(function(w) { return w.id === 31 }).length, 1)
        verify(!queue.some(function(w) { return w.id === 41 }))
        snap.sourceMonitorKey = "right"
        const right = Logic.workspaceCandidates(snap, [])
        verify(right.some(function(w) { return w.id === 41 }))
        verify(!right.some(function(w) { return w.id === 21 || w.id === 31 }))
    }
    function test_arrivalAppendsWithoutReorderingOrChangingSelection() {
        const snap = desktop(false)
        const before = Logic.workspaceCandidates(snap, [])
        const state = selecting(before, "workspace:4")
        snap.workspaces.push(workspace(21, "left"))
        const after = Logic.reconcileWorkspaceCandidates(snap, ["workspace:3", "workspace:21"], keys(before))
        compare(keys(after), keys(before).concat(["workspace:21"]))
        const updated = Logic.refreshSession(state, 9, keys(after))
        compare(after[updated.selectedIndex].key, "workspace:4")
        compare(Logic.confirmSession(updated, 9).targetKey, "workspace:4")
        compare(Logic.confirmSession(selecting(after, "workspace:21"), 9).targetKey, "workspace:21")
    }
    function test_departurePreservesAnotherSelectedWorkspace() {
        const snap = desktop(false)
        snap.workspaces.push(workspace(21, "left"))
        const before = Logic.workspaceCandidates(snap, ["workspace:3", "workspace:21"])
        const state = selecting(before, "workspace:4")
        snap.workspaces.find(function(w) { return w.id === 21 }).monitorKey = "right"
        const after = Logic.reconcileWorkspaceCandidates(snap, [], keys(before))
        const updated = Logic.refreshSession(state, 9, keys(after))
        compare(after[updated.selectedIndex].key, "workspace:4")
        compare(Logic.confirmSession(updated, 9).targetKey, "workspace:4")
        compare(Logic.workspaceActivationTarget(snap, "workspace:21", "left", 10), null)
    }
    function test_selectedGuestDepartureCancelsInsteadOfSwitchingScreen() {
        const snap = desktop(false)
        snap.workspaces.push(workspace(21, "left"))
        const before = Logic.workspaceCandidates(snap, [])
        const state = selecting(before, "workspace:21")
        snap.workspaces.find(function(w) { return w.id === 21 }).monitorKey = "right"
        const after = Logic.reconcileWorkspaceCandidates(snap, [], keys(before))
        const cancelled = Logic.refreshSession(state, 9, keys(after))
        compare(cancelled.phase, "idle")
        compare(Logic.confirmSession(cancelled, 9).phase, "idle")
    }
    function test_selectedGuestRenumberingCancelsAndReopenUsesNewId() {
        const snap = desktop(false)
        snap.workspaces.push(workspace(21, "left"))
        const before = Logic.workspaceCandidates(snap, [])
        const state = selecting(before, "workspace:21")
        snap.workspaces = snap.workspaces.filter(function(w) { return w.id !== 21 }).concat([workspace(6, "left")])
        const after = Logic.reconcileWorkspaceCandidates(snap, [], keys(before))
        verify(!keys(after).includes("workspace:21"))
        verify(keys(after).includes("workspace:6"))
        compare(Logic.refreshSession(state, 9, keys(after)).phase, "idle")
        compare(Logic.workspaceActivationTarget(snap, "workspace:21", "left", 10), null)
        compare(Logic.workspaceActivationTarget(snap, "workspace:6", "left", 10).id, 6)
    }
    function test_vanishedGuestIsNotRecreatedInAnotherBlock() {
        const snap = desktop(false)
        snap.workspaces.push(workspace(11, "left"))
        snap.workspaces = snap.workspaces.filter(function(w) { return w.id !== 11 })
        compare(Logic.workspaceActivationTarget(snap, "workspace:11", "left", 10), null)
        snap.workspaces.push(workspace(21, "left"))
        snap.workspaces = snap.workspaces.filter(function(w) { return w.id !== 21 })
        compare(Logic.workspaceActivationTarget(snap, "workspace:21", "left", 10), null)
    }
    function test_refreshIgnoresOldOrCompletedSession() {
        const queue = Logic.workspaceCandidates(desktop(false), [])
        const state = selecting(queue, "workspace:3")
        compare(Logic.refreshSession(state, 8, []), state)
        compare(Logic.refreshSession(state, 9, keys(queue)), state)
        const committed = Logic.confirmSession(state, 9)
        compare(Logic.refreshSession(committed, 9, []), committed)
    }
}
