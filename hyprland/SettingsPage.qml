pragma ComponentBehavior: Bound
import QtQuick
import "../package/contents/ui" as Shared
import "../package/contents/ui/studio" as Studio
import "../package/contents/ui/studio/Theme.js" as Theme

// Hyprland settings window: the shared studio over a draft, with Reset, Close
// and Apply. Apply saves overrides; Reset returns to the configured defaults.
Rectangle {
    id: page
    color: Theme.bg
    property var draft: ({})
    property var savedDraft: ({})
    property var defaults: ({})
    property var screenNames: []
    property string errorMessage: ""
    property Component commandSourceComponent: null
    signal apply(var draft)
    signal reset
    signal close

    // Reads this machine with the draft, for the preview and device lists.
    Shared.MonitorCore {
        id: previewMonitor
        cfg: page.draft
        onScreen: studio.onScreen
        active: studio.onScreen
        commandSourceComponent: page.commandSourceComponent
        writeConfig: (key, value) => page.draft = Object.assign({}, page.draft, {
                [key]: value
            })
        systemAccent: page.draft.accentColor ?? "#89b4fa"
        systemTextColor: page.draft.textColor ?? "#cdd6f4"
    }

    Studio.Studio {
        id: studio
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        env: "hypr"
        draft: page.draft
        defaults: Object.keys(page.defaults).length ? page.defaults : page.draft
        screenNames: page.screenNames
        liveMonitor: previewMonitor
        previewAccent: page.draft.accentColor ?? "#89b4fa"
        canDiscard: Object.keys(page.draft).some(k => JSON.stringify(page.draft[k]) !== JSON.stringify(page.savedDraft[k]))
        onEdited: next => page.draft = next
        onDiscard: page.draft = Object.assign({}, page.savedDraft)
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 60
        color: Theme.panel
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.line
        }
        Text {
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - buttons.width - 60
            text: page.errorMessage !== "" ? page.errorMessage : "Apply saves your changes. Reset returns to the defaults in shell.qml."
            color: page.errorMessage !== "" ? "#ff8a8a" : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        Row {
            id: buttons
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Studio.StudioButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Reset"
                areaName: "resetSettings"
                onClicked: page.reset()
            }
            Studio.StudioButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Close"
                areaName: "closeSettings"
                onClicked: page.close()
            }
            Studio.StudioButton {
                anchors.verticalCenter: parent.verticalCenter
                primary: true
                text: "Apply"
                areaName: "applySettings"
                onClicked: page.apply(page.draft)
            }
        }
    }
}
