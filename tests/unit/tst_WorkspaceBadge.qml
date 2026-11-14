import QtQuick
import QtTest
import "../../dist/plugin/generated/Logic.mjs" as Logic

TestCase {
    name: "WorkspaceBadge"

    function test_localAndVisiting_data() {
        return [
            {tag: "first-slot", start: 1, id: 1, number: 1, visiting: false},
            {tag: "last-slot-zero", start: 1, id: 10, number: 0, visiting: false},
            {tag: "second-monitor-first", start: 11, id: 11, number: 1, visiting: false},
            {tag: "second-monitor-zero", start: 11, id: 20, number: 0, visiting: false},
            {tag: "third-monitor-zero", start: 21, id: 30, number: 0, visiting: false},
            {tag: "guest-after-block", start: 11, id: 21, number: 21, visiting: true},
            {tag: "guest-zero", start: 11, id: 30, number: 30, visiting: true},
            {tag: "guest-before-block", start: 11, id: 10, number: 10, visiting: true},
            {tag: "guest-short-global-id", start: 21, id: 1, number: 1, visiting: true},
            {tag: "unknown-block", start: null, id: 20, number: 20, visiting: false},
            {tag: "named-workspace", start: 1, id: -1337, number: null, visiting: false}
        ]
    }
    function test_localAndVisiting(data) {
        const badge = Logic.workspaceBadge({id: data.id, localSlot: 1, homeMonitorKey: "old-screen"}, {slotStart: data.start})
        compare(badge.number, data.number)
        compare(badge.visiting, data.visiting)
    }
    function test_moveAndRenumberUsesCurrentBlock() {
        const workspace = {id: 20, localSlot: 10, homeMonitorKey: "old-screen"}
        compare(Logic.workspaceBadge(workspace, {slotStart: 11}), {number: 0, visiting: false})
        compare(Logic.workspaceBadge(workspace, {slotStart: 1}), {number: 20, visiting: true})
        workspace.id = 8
        compare(Logic.workspaceBadge(workspace, {slotStart: 1}), {number: 8, visiting: false})
        compare(Logic.workspaceBadge(workspace, undefined), {number: 8, visiting: false})
    }
}
