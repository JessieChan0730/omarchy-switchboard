import QtQuick

Item {
    id: controller
    property string requestedPath: ""
    readonly property string path: retainedPath
    readonly property bool ready: retained.status === Image.Ready && retainedPath !== ""
    property string retainedPath: ""

    function fileUrl(path: string): string {
        return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : ""
    }
    onRequestedPathChanged: if (requestedPath === "") retainedPath = ""

    // Pin the decoded thumbnail independently of overlay surfaces and card
    // sizes. The next image loads before replacing the current wallpaper.
    Image {
        id: incoming
        visible: false
        source: controller.fileUrl(controller.requestedPath)
        // BackgroundMedia explicitly requests 0x0 (native), while Image's
        // default is -1x-1. Qt treats those as different cache keys.
        sourceSize: Qt.size(0, 0)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        onStatusChanged: {
            if (status === Image.Ready) controller.retainedPath = controller.requestedPath
            else if (status === Image.Error) controller.retainedPath = ""
        }
    }
    Image {
        id: retained
        visible: false
        source: controller.fileUrl(controller.retainedPath)
        sourceSize: Qt.size(0, 0)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }
}
