pragma ComponentBehavior: Bound
import QtQuick
import "../package/contents/ui" as Shared
import "../package/contents/ui/studio" as Studio
import "../package/contents/ui/studio/Theme.js" as Theme
import "../package/contents/ui/Sections.js" as Sections
import "Configuration.js" as Configuration

// Hyprland settings window: the shared studio over a draft, with Reset, Close
// and Apply. Apply saves overrides; Reset returns to the configured defaults.
// With several cards the footer switches between them; each keeps its
// own draft until Apply saves them all.
Rectangle {
    id: page
    color: Theme.bg
    // The card being edited.
    property var draft: ({})
    // Every card as edited (the current one is `draft`) and as saved.
    property var drafts: [draft]
    property var savedCards: []
    property int cardIndex: 0
    readonly property var savedDraft: savedCards[cardIndex] || ({})
    property var defaults: ({})
    property var screenNames: []
    property string errorMessage: ""
    property Component commandSourceComponent: null
    signal apply(var drafts)
    signal reset
    signal close
    // Apply, then arrange cards and sections on the desktop.
    signal arrange

    function open(cards, index) {
        savedCards = cards;
        drafts = cards.map(c => Object.assign({}, c));
        cardIndex = Math.min(index, cards.length - 1);
        draft = drafts[cardIndex];
    }
    // Keep the current draft, with what all cards share copied to the others.
    function stash() {
        const next = drafts.slice();
        next[cardIndex] = draft;
        drafts = Configuration.shareFrom(draft, next);
    }
    function showCard(index) {
        stash();
        cardIndex = index;
        draft = drafts[index];
    }
    // A new card starts as a copy of this one on the other side.
    function addCard() {
        stash();
        drafts = drafts.concat([Object.assign({}, draft, {
                hAnchor: draft.hAnchor === "left" ? "right" : "left",
                layoutMode: "auto",
                sectionPositions: "{}"
            })]);
        showCard(drafts.length - 1);
    }
    function removeCard() {
        if (drafts.length < 2)
            return;
        stash();
        drafts = drafts.filter((d, i) => i !== cardIndex);
        cardIndex = Math.min(cardIndex, drafts.length - 1);
        draft = drafts[cardIndex];
    }
    function cardName(card, index) {
        if (!card)
            return "";
        const ids = Sections.parse(card.sections, card.activeSection);
        return (index + 1) + " · " + Sections.title(ids[0], card) + (ids.length > 1 ? " +" + (ids.length - 1) : "");
    }

    // Reads this machine with the draft, for the preview and device lists.
    Shared.MonitorCore {
        id: previewMonitor
        cfg: page.draft
        onScreen: studio.onScreen
        discoverSensors: studio.onScreen
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
        canDiscard: page.drafts.length !== page.savedCards.length || Object.keys(page.draft).some(k => JSON.stringify(page.draft[k]) !== JSON.stringify(page.savedDraft[k]))
        onEdited: next => page.draft = next
        onDiscard: page.open(page.savedCards, page.cardIndex)
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
        // Cards: pick the one to edit, add one, remove this one.
        Row {
            id: cards
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Repeater {
                model: page.drafts.length
                Studio.StudioButton {
                    required property int index
                    compact: true
                    primary: index === page.cardIndex
                    text: page.cardName(index === page.cardIndex ? page.draft : page.drafts[index], index)
                    areaName: "card_" + index
                    tooltip: "Edit this card"
                    onClicked: if (index !== page.cardIndex)
                        page.showCard(index)
                }
            }
            Studio.StudioButton {
                anchors.verticalCenter: parent.verticalCenter
                compact: true
                text: "+ Card"
                areaName: "addCard"
                tooltip: "Another card with its own sections, look and place on screen"
                onClicked: page.addCard()
            }
            Studio.StudioButton {
                anchors.verticalCenter: parent.verticalCenter
                compact: true
                visible: page.drafts.length > 1
                text: "Remove"
                areaName: "removeCard"
                tooltip: "Remove the card being edited"
                onClicked: page.removeCard()
            }
        }
        Text {
            anchors.left: cards.right
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - cards.width - buttons.width - 76
            text: page.errorMessage !== "" ? page.errorMessage : page.drafts.length > 1 ? "Each card has its own sections, look and placement; devices, hosts, commands and sensor choices are shared." : "Apply saves your changes. Reset returns to the defaults in shell.qml."
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
                text: "Arrange on desktop"
                areaName: "arrangeDesktop"
                tooltip: "Applies your changes, closes this window and lets you drag cards (by their bar and right edge) and sections on the desktop"
                onClicked: {
                    page.stash();
                    page.apply(page.drafts);
                    page.arrange();
                }
            }
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
                onClicked: {
                    page.stash();
                    page.apply(page.drafts);
                }
            }
        }
    }
}
