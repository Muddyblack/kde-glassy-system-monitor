import QtQuick
import QtTest
import "../package/contents/ui/studio" as Studio
import "../package/contents/ui/studio/Schema.js" as Schema

// The settings studio: navigation, search, the section list and looks.
Item {
    id: root
    width: 1280
    height: 820

    property var draft: ({})
    property var defaults: ({})
    function loadDefaults() {
        const x = new XMLHttpRequest();
        x.open("GET", Qt.resolvedUrl("../package/contents/config/main.xml"), false);
        x.send();
        const out = {};
        const re = /<entry\s+name="([^"]+)"\s+type="([^"]+)"\s*>\s*<default>([^<]*)<\/default>/g;
        let m;
        while ((m = re.exec(x.responseText)) !== null)
            out[m[1]] = m[2] === "Bool" ? m[3] === "true" : (m[2] === "Int" || m[2] === "Double") ? Number(m[3]) : m[3];
        return out;
    }

    Studio.Studio {
        id: studio
        anchors.fill: parent
        draft: root.draft
        defaults: root.defaults
        onEdited: next => root.draft = next
    }

    TestCase {
        name: "Studio"
        when: windowShown

        function init() {
            root.defaults = root.loadDefaults();
            root.draft = Object.assign({}, root.defaults, {
                sections: "cpu,memory,network"
            });
            studio.query = "";
            studio.selectTab("layout");
            wait(50);
        }
        function find(name, item) {
            item = item || studio;
            if (item.objectName === name)
                return item;
            for (const child of item.children) {
                const hit = find(name, child);
                if (hit)
                    return hit;
            }
            return null;
        }
        function sectionList() {
            let list = null;
            const walk = item => {
                if (!list && item.enabledIds !== undefined && item.moveSection !== undefined)
                    list = item;
                for (const child of item.children)
                    walk(child);
            };
            walk(studio);
            return list;
        }

        function test_sensorPickerEditsAndKeepsDelegatesDuringSamples() {
            studio.selectTab("cpu");
            wait(50);
            const picker = find("sensorPicker_cpu");
            verify(picker);
            compare(picker.selected, [], "CPU shows no extra readings by default");
            picker.choose(["cpu:power"]);
            picker.setOpen("Power draw", true);
            wait(30);
            picker.rename("cpu:power", "CPU package draw");
            compare(JSON.parse(root.draft.sensorNames)["cpu:power"], "CPU package draw");
            const control = find("sensor_cpu:power");
            verify(control);
            const original = studio.sensorMonitor.powerSources;
            studio.sensorMonitor.powerSources = original.map(s => Object.assign({}, s, {
                    watts: 42
                }));
            wait(30);
            const current = find("sensor_cpu:power");
            studio.sensorMonitor.powerSources = original.map(s => Object.assign({}, s, {
                    watts: 43
                }));
            wait(30);
            compare(find("sensor_cpu:power"), current, "a new reading preserves the input delegate");
            picker.choose([]);
            compare(JSON.parse(root.draft.sensorSelection).cpu, []);
            picker.choose(null);
            verify(picker.automatic);
            // A device's checkbox chooses all of its readings.
            find("sensorGroup_Power draw").toggled(true);
            compare(picker.selected.length, 3);
            find("sensorGroup_Power draw").toggled(false);
            compare(picker.selected, []);
        }

        function test_manualStartsFromTheGridAndDrags() {
            root.draft = Object.assign({}, root.draft, {
                layoutColumns: 2
            });
            wait(50);
            studio.update({
                layoutMode: "manual"
            });
            wait(50);
            verify(find("row_sectionPositions"));
            const seeded = JSON.parse(root.draft.sectionPositions);
            compare(Object.keys(seeded).sort(), ["cpu", "memory", "network"]);
            compare(seeded.cpu.y, seeded.memory.y, "side by side as in the grid");
            verify(seeded.memory.x > seeded.cpu.x);
            // The preview writes a drag as the new position.
            find("previewWidget").sectionMoved("cpu", {
                x: 40,
                y: 12,
                width: 260
            });
            compare(JSON.parse(root.draft.sectionPositions).cpu, {
                x: 40,
                y: 12,
                width: 260
            });
            const x = find("position_cpu_x");
            verify(x);
            compare(x.value, "40");
            // Back to automatic and Manual again keeps what was placed.
            studio.update({
                layoutMode: "auto"
            });
            studio.update({
                layoutMode: "manual"
            });
            compare(JSON.parse(root.draft.sectionPositions).cpu.x, 40);
        }

        function test_everyTabIsReachable() {
            root.draft = Object.assign({}, root.draft, {
                sections: Schema.GROUPS.sections.join(",")
            });
            wait(30);
            for (const tab of Schema.TABS) {
                studio.selectTab(tab.id);
                compare(studio.currentTab, tab.id);
            }
            compare(Schema.MAIN_TABS.map(t => t.id), ["presets", "layout", "appearance", "sections", "performance", "about"]);
        }

        // Only switched-on sections get a tab; a disabled one resolves away.
        function test_sectionTabsFollowEnabledSections() {
            studio.selectTab("ping");
            compare(studio.currentTab, "cpu");
            compare(studio.subTabs.map(t => t.id), ["cpu", "memory", "network"]);
        }

        function test_searchFindsRowsAcrossTabs() {
            studio.query = "download";
            wait(50);
            verify(studio.anyResults);
            studio.query = "no such setting anywhere";
            wait(50);
            verify(!studio.anyResults);
        }

        function test_toggleKeepsAtLeastOneSection() {
            root.draft = Object.assign({}, root.draft, {
                sections: "cpu"
            });
            wait(30);
            sectionList().toggle("cpu");
            compare(root.draft.sections, "cpu");
            sectionList().toggle("gpu");
            compare(root.draft.sections, "cpu,gpu");
        }

        function test_dropMovesToNearestSlot() {
            const list = sectionList();
            list.dropSection("network", 0);
            compare(root.draft.sections, "network,cpu,memory");
            list.dropSection("network", list.rowStep * 1.4);
            compare(root.draft.sections, "cpu,network,memory");
            list.dropSection("cpu", 99999);
            compare(root.draft.sections, "network,memory,cpu", "a drop below the list lands last");
        }

        function test_sizesSpansAndStylesPerSection() {
            const list = sectionList();
            list.setSize("cpu", "l");
            compare(root.draft.sectionSizes, "cpu:l");
            list.setSize("cpu", "m");
            compare(root.draft.sectionSizes, "", "medium is the default and is not stored");
            list.toggleSpan("network");
            compare(root.draft.sectionSpans, "network");
            list.setStyle("memory", "donut");
            compare(root.draft.sectionStyles, "memory:donut");
        }

        function test_savedLookStaysInSettings() {
            studio.selectTab("presets");
            wait(50);
            let gallery = null;
            const walk = item => {
                if (!gallery && item.storeSaved !== undefined)
                    gallery = item;
                for (const child of item.children)
                    walk(child);
            };
            walk(studio);
            verify(gallery);
            gallery.storeSaved([
                {
                    name: "Mine",
                    settings: {
                        cpuColor: "#123456"
                    }
                }
            ]);
            compare(JSON.parse(root.draft.userPresets)[0].name, "Mine");
            compare(gallery.saved.length, 1);
        }

        function test_presetTilesSurviveRepeatedEdits() {
            studio.selectTab("presets");
            wait(50);
            const tile = find("look_glassy");
            verify(tile);
            const gallery = tile.parent.parent;
            const model = gallery.all;
            verify(model && model.length > 0);
            const preview = tile.look;
            for (let i = 0; i < 100; i++) {
                studio.update({
                    lineWidth: 1 + (i % 40) / 10,
                    bgRadiusTL: i % 30
                });
                verify(gallery.all === model, "Draft edits must preserve the gallery model");
                verify(find("look_glassy") === tile, "Draft edits must preserve preset tiles");
                verify(tile.look === preview, "Unchanged preset settings must not refresh its charts");
                wait(1);
            }
            studio.update({
                networkInterface: "regression0"
            });
            compare(tile.look.networkInterface, "regression0", "Device settings still reach previews");
            studio.update({
                userPresets: JSON.stringify([
                    {
                        name: "Regression",
                        settings: {
                            cpuColor: "#123456"
                        }
                    }
                ])
            });
            verify(find("look_saved0"), "Changing saved looks must still refresh the gallery");
            studio.update({
                userPresets: "[]"
            });
            verify(!find("look_saved0"), "Removing a saved look must remove its tile");
        }
    }
}
