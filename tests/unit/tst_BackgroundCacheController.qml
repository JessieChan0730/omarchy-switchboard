import QtQuick
import QtTest
import "../../dist/plugin/controllers" as Controllers

TestCase {
    id: test
    name: "BackgroundPreviewCache"
    readonly property string red: decodeURIComponent(Qt.resolvedUrl("../fixtures/background-red.svg").toString().replace(/^file:\/\//, ""))
    readonly property string blue: decodeURIComponent(Qt.resolvedUrl("../fixtures/background-blue.svg").toString().replace(/^file:\/\//, ""))
    Component { id: factory; Controllers.BackgroundCacheController {} }
    property var controller: null

    function init(): void {
        controller = createTemporaryObject(factory, test)
        verify(controller !== null)
    }
    function load(path: string): void {
        controller.requestedPath = path
        tryCompare(controller, "path", path)
        tryCompare(controller, "ready", true)
    }
    function test_preloads_and_retains_without_visible_surface(): void {
        controller.visible = false
        load(red)
        wait(50)
        compare(controller.path, red)
        verify(controller.ready)
    }
    function test_wallpaper_replacement_is_published_when_ready(): void {
        load(red)
        load(blue)
        compare(controller.path, blue)
        verify(controller.ready)
    }
    function test_newer_request_wins_over_pending_decode(): void {
        controller.requestedPath = red
        controller.requestedPath = blue
        tryCompare(controller, "path", blue)
        tryCompare(controller, "ready", true)
        wait(50)
        compare(controller.path, blue)
    }
    function test_clear_cannot_publish_an_old_request(): void {
        load(red)
        controller.requestedPath = blue
        controller.requestedPath = ""
        wait(50)
        compare(controller.path, "")
        verify(!controller.ready)
    }
    function test_file_urls_encode_special_characters(): void {
        compare(controller.fileUrl("/tmp/background '?#%.png"), "file:///tmp/background%20'%3F%23%25.png")
    }
}
