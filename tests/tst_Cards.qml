import QtQuick
import QtTest
import "../hyprland" as Hypr
import "../hyprland/Configuration.js" as Configuration

// Several cards on Quickshell: how hyprland.json holds them, what they
// share, and the settings window's card switcher.
Item {
    id: root
    width: 1280
    height: 820

    property var applied: null

    Hypr.SettingsPage {
        id: page
        anchors.fill: parent
        onApply: drafts => root.applied = drafts
    }

    TestCase {
        name: "Cards"
        when: windowShown

        readonly property var first: ({
                sections: "cpu,memory",
                hAnchor: "right",
                verticalPosition: 0.08,
                targets: "1.1.1.1",
                cardStyle: "glass"
            })

        function test_savedFileSplitsAndJoins() {
            const saved = Configuration.split({
                sections: "cpu",
                cards: [
                    {
                        sections: "sensors",
                        hAnchor: "left",
                        targets: "evil.example"
                    },
                    "junk"]
            });
            compare(saved.main, {
                sections: "cpu"
            });
            compare(saved.cards, [
                {
                    sections: "sensors",
                    hAnchor: "left"
                }
            ], "shared settings never come from another card");
            compare(Configuration.join({
                sections: "cpu"
            }, []), {
                sections: "cpu"
            }, "one card saves as before");
        }
        function test_cardsInheritAndShare() {
            const all = Configuration.cards(first, [
                {
                    sections: "sensors,power",
                    hAnchor: "left"
                }
            ]);
            compare(all.length, 2);
            compare(all[1].cardStyle, "glass", "a card follows the first one's look unless changed");
            compare(all[1].targets, "1.1.1.1");
            const kept = Configuration.cardChanges(all[0], all[1]);
            compare(kept.sections, "sensors,power");
            compare(kept.hAnchor, "left");
            compare(kept.verticalPosition, all[0].verticalPosition, "its place is its own even where it matches");
            verify(!("cardStyle" in kept), "the look follows the first card");
            verify(!("targets" in kept), "shared settings stay with the first card");
            compare(Configuration.coreConfig(all).sections, "cpu,memory,sensors,power", "one core samples every card's sections");
            const shared = Configuration.shareFrom(Object.assign({}, all[1], {
                targets: "9.9.9.9"
            }), all);
            compare(shared[0].targets, "9.9.9.9");
            compare(shared[0].sections, "cpu,memory", "but not the card's own settings");
        }
        function test_settingsSwitchAddAndRemoveCards() {
            page.open([first], 0);
            compare(page.drafts.length, 1);
            page.addCard();
            compare(page.cardIndex, 1);
            compare(page.draft.hAnchor, "left", "a new card goes to the other side");
            page.draft = Object.assign({}, page.draft, {
                sections: "sensors",
                targets: "9.9.9.9"
            });
            page.showCard(0);
            compare(page.draft.targets, "9.9.9.9", "shared settings follow the last edit");
            compare(page.draft.sections, "cpu,memory");
            compare(page.cardName(page.drafts[1], 1), "2 · Sensors");
            page.stash();
            page.apply(page.drafts);
            compare(root.applied.length, 2);
            compare(root.applied[1].sections, "sensors");
            page.showCard(1);
            page.removeCard();
            compare(page.drafts.length, 1);
            compare(page.draft.sections, "cpu,memory");
        }
    }
}
