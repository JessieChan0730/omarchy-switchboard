import QtQuick
import QtTest
import "../../dist/plugin/generated/Logic.mjs" as Logic

TestCase {
    name: "ApplicationGroups"
    function desktop() {
        return Logic.parseSnapshot({
            monitors: [{key: "left"}, {key: "right"}],
            workspaces: [{key: "workspace:1", id: 1, monitorKey: "left"},
                {key: "workspace:2", id: 2, monitorKey: "left"}, {key: "workspace:11", id: 11, monitorKey: "right"}],
            windows: [
                {key: "t1", address: "0x1", appId: "terminal", workspaceKey: "workspace:1", monitorKey: "left"},
                {key: "b1", address: "0x2", appId: "Browser", applicationId: "browser.desktop", workspaceKey: "workspace:1", monitorKey: "left"},
                {key: "t2", address: "0x3", appId: "Terminal", workspaceKey: "workspace:1", monitorKey: "left"},
                {key: "b2", address: "0x4", appId: "browser-other-class", applicationId: "browser.desktop", workspaceKey: "workspace:1", monitorKey: "left"},
                {key: "t3", address: "0x5", appId: "terminal", workspaceKey: "workspace:1", monitorKey: "left"},
                {key: "other-workspace", address: "0x6", appId: "editor", workspaceKey: "workspace:2", monitorKey: "left"},
                {key: "other-screen", address: "0x7", appId: "editor", workspaceKey: "workspace:11", monitorKey: "right"}
            ], currentWindowKey: "t2", currentWorkspaceKey: "workspace:1", sourceMonitorKey: "left"
        })
    }
    function test_groupingAndMru() {
        const groups = Logic.applicationCandidates(desktop(), ["b2", "t3", "b1", "t1"])
        compare(groups.map(function(a) { return a.key }), ["application:terminal", "application:browser.desktop"])
        compare(groups[0].windows.map(function(w) { return w.key }), ["t2", "t3", "t1"])
        compare(groups[1].windows.map(function(w) { return w.key }), ["b2", "b1"])
        compare(Logic.initialSelection(groups, "application:terminal", 1), 1)
        compare(Logic.initialSelection(groups, "application:terminal", -1), 1)
    }
    function test_windowEntryStartsFromFocusedOrHighlightedApp() {
        const groups = Logic.applicationCandidates(desktop(), ["b2", "t3", "b1", "t1"])
        compare(Logic.initialSelection(groups[0].windows, "t2", 1), 1)
        compare(Logic.initialSelection(groups[0].windows, "t2", -1), 2)
        compare(Logic.initialSelection(groups[1].windows, "t2", 1), 0)
        compare(Logic.initialSelection(groups[1].windows, "t2", -1), 1)
        compare(Logic.parseOpenRequest('{"mode":"app-windows","direction":-1}').mode, "app-windows")
    }
    function test_unknownAppsDoNotMergeByTitle() {
        const snap = desktop()
        snap.windows[0].appId = ""; snap.windows[0].applicationId = ""
        snap.windows[2].appId = ""; snap.windows[2].applicationId = ""
        const groups = Logic.applicationCandidates(snap, [])
        verify(groups.some(function(a) { return a.key === "application:t1" }))
        verify(groups.some(function(a) { return a.key === "application:t2" }))
    }
    function test_refreshKeepsGroupsAndCancelsDepartedWindow() {
        const snap = desktop()
        const groups = Logic.applicationCandidates(snap, ["b2", "t3", "b1", "t1"])
        let session = Logic.resolveSession(Logic.prepareSession(1, {mode: "app-windows", direction: 1}, {}),
            1, groups[0].windows.map(function(w) { return w.key }), "t2", false)
        compare(session.selectedIndex, 1)
        snap.windows.find(function(w) { return w.key === "t3" }).workspaceKey = "workspace:2"
        snap.windows.push({key: "new", address: "0x8", appId: "editor", applicationId: "editor", workspaceKey: "workspace:1", monitorKey: "left"})
        const refreshed = Logic.reconcileApplicationCandidates(snap, ["new", "t1"], groups.map(function(a) { return a.key }))
        compare(refreshed.map(function(a) { return a.key }), ["application:terminal", "application:browser.desktop", "application:editor"])
        compare(Logic.refreshSession(session, 1, refreshed[0].windows.map(function(w) { return w.key })).phase, "idle")
        verify(refreshed.every(function(a) { return a.windows.every(function(w) { return w.workspaceKey === "workspace:1" }) }))
    }
}
