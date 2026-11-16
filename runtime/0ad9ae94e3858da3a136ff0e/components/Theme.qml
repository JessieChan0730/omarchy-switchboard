import QtQuick
import qs.Commons as Commons

QtObject {
    // Omarchy exposes nested tokens as QtObject; qmllint cannot see their fields.
    // Limit this suppression to the dynamic host token boundary.
    // qmllint disable missing-property
    readonly property color backgroundColor: Commons.Color.menu.background
    readonly property color foregroundColor: Commons.Color.menu.text
    readonly property color borderColor: Commons.Color.menu.border
    readonly property string fontFamily: Commons.Style.font.family
    readonly property int titleSize: Commons.Style.font.title
    readonly property int bodySize: Commons.Style.font.body
    readonly property int spacing: Commons.Style.spacing.md
    // qmllint enable missing-property

    readonly property color accentColor: Commons.Color.accent
    readonly property int cornerRadius: Commons.Style.cornerRadius
}
