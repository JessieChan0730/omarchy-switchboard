import QtQuick
import QtTest
import "../../dist/plugin/controllers" as Controllers

TestCase {
    id: test
    name: "CaptureRetryRecovery"
    QtObject { id: originalSource }
    QtObject { id: replacementSource }
    Component { id: factory; Controllers.CaptureRetryController {} }
    property var controller: null

    function init(): void {
        controller = createTemporaryObject(factory, test, {active: true, source: originalSource})
        verify(controller !== null)
        verify(controller.captureEnabled)
    }
    function test_transientFailureRecoversWithSameSource(): void {
        controller.captureFailed()
        verify(!controller.captureEnabled)
        tryCompare(controller, "captureEnabled", true, 1000)
        compare(controller.source, originalSource)
        compare(controller.retryCount, 1)
        controller.hasContent = true
        tryCompare(controller, "retryCount", 0, 3000)

        // A later failure receives a fresh budget after stable recovery.
        controller.captureFailed()
        tryCompare(controller, "captureEnabled", true, 1000)
        compare(controller.retryCount, 1)
    }
    function test_persistentFailureAndBriefFramesExhaustBudget(): void {
        for (let attempt = 1; attempt <= 3; attempt++) {
            controller.captureFailed()
            verify(!controller.captureEnabled)
            tryCompare(controller, "captureEnabled", true, 2000)
            compare(controller.retryCount, attempt)
            controller.hasContent = true
            wait(50)
            compare(controller.retryCount, attempt)
            controller.hasContent = false
        }
        controller.captureFailed()
        wait(1250)
        verify(!controller.captureEnabled)
        compare(controller.retryCount, 3)
    }
    function test_hiddenCardCancelsRetryAndCanRetryWhenVisibleAgain(): void {
        controller.captureFailed()
        controller.active = false
        wait(600)
        verify(!controller.captureEnabled)
        compare(controller.retryCount, 0)

        controller.active = true
        verify(controller.captureEnabled)
        controller.captureFailed()
        tryCompare(controller, "captureEnabled", true, 1000)
        compare(controller.retryCount, 1)
    }
    function test_missingSourceCancelsPendingRetry(): void {
        controller.captureFailed()
        controller.source = null
        wait(600)
        verify(!controller.captureEnabled)
        compare(controller.retryCount, 0)
        controller.source = originalSource
        verify(controller.captureEnabled)
    }
    function test_replacementSourceDoesNotReceiveOldRetry(): void {
        controller.captureFailed()
        controller.source = replacementSource
        verify(controller.captureEnabled)
        wait(600)
        compare(controller.retryCount, 0)
        compare(controller.source, replacementSource)
    }
    function test_duplicateStopDoesNotConsumeExtraRetries(): void {
        controller.captureFailed()
        controller.captureFailed()
        controller.captureFailed()
        tryCompare(controller, "captureEnabled", true, 1000)
        compare(controller.retryCount, 1)
    }
}
