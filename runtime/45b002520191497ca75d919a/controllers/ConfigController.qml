import QtQuick
import Quickshell
import Quickshell.Io
import "../generated/Logic.mjs" as Logic

Item {
    id: controller
    property var shell: null
    property string pluginId: "jessie.switchboard"
    property bool defaultBindingsEnabled: false
    // qmllint disable missing-property
    property var settings: Logic.parseConfig({})
    // qmllint enable missing-property
    property var entry: ({})
    property bool supported: true
    signal invalidConfig()
    onDefaultBindingsEnabledChanged: {
        if (supported) {
            // qmllint disable missing-property
            settings = Logic.parseConfig(Object.assign({bindingsEnabled: defaultBindingsEnabled}, entry))
            // qmllint enable missing-property
        }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const config = JSON.parse(text())
                const entries = Array.isArray(config.plugins) ? config.plugins : []
                controller.entry = entries.find(function(e) { return e && e.id === controller.pluginId }) || {}
                // qmllint disable missing-property
                controller.settings = Logic.parseConfig(Object.assign({bindingsEnabled: controller.defaultBindingsEnabled}, controller.entry))
                // qmllint enable missing-property
                controller.supported = true
            } catch (error) {
                controller.supported = false
                controller.invalidConfig()
            }
        }
    }
    function save(changes: var): bool {
        if (!supported || !shell || typeof shell.updateEntryInline !== "function") return false
        const next = Object.assign({}, entry, changes)
        try {
            // qmllint disable missing-property
            Logic.parseConfig(next)
            // qmllint enable missing-property
        } catch (error) { return false }
        return shell.updateEntryInline(pluginId, next)
    }
}
