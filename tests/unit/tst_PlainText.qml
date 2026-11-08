import QtQuick
import QtTest
import "../../dist/plugin/components" as Components

TestCase {
    name: "PlainTextRendering"

    Components.PlainText {
        id: title
        text: "<b>Window title</b>"
        font.pixelSize: 16
    }
    Text {
        id: renderedTitle
        text: "Window title"
        font.pixelSize: 16
        textFormat: Text.PlainText
    }

    function test_markupRemainsVisibleText(): void {
        // AutoText would remove the tags and render a shorter, formatted title.
        verify(title.contentWidth > renderedTitle.contentWidth)
        compare(title.textFormat, Text.PlainText)
        compare(title.text, "<b>Window title</b>")
    }
}
