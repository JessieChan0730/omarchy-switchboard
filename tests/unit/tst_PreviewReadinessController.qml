import QtQuick
import QtTest
import "../../dist/plugin/controllers" as Controllers

TestCase {
    name: "PreviewReadinessController"
    Controllers.PreviewReadinessController { id: readiness }

    function init(): void {
        readiness.active = false
        readiness.sourceKey = "window:first"
        readiness.hasContent = false
    }
    function cleanup(): void { readiness.active = false }

    function test_firstFrameSkipsTheIconFallback(): void {
        readiness.active = true
        wait(50)
        verify(!readiness.ready)
        verify(!readiness.fallbackReady)
        readiness.hasContent = true
        verify(readiness.ready)
        wait(200)
        verify(!readiness.fallbackReady)
    }
    function test_missingPreviewEventuallyShowsFallback(): void {
        readiness.active = true
        wait(50)
        verify(!readiness.ready)
        tryCompare(readiness, "ready", true, 300)
        verify(readiness.fallbackReady)
    }
    function test_closingCancelsFirstFrameWait(): void {
        readiness.active = true
        wait(50)
        readiness.active = false
        wait(200)
        verify(!readiness.ready)
        verify(!readiness.fallbackReady)
        readiness.active = true
        verify(!readiness.ready)
    }
    function test_newWindowDoesNotInheritFallback(): void {
        readiness.active = true
        tryCompare(readiness, "fallbackReady", true, 300)
        readiness.sourceKey = "window:second"
        verify(!readiness.ready)
        wait(50)
        verify(!readiness.fallbackReady)
        readiness.hasContent = true
        verify(readiness.ready)
    }
}
