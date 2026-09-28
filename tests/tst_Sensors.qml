import QtQuick
import QtTest
import "../package/contents/ui" as Ui
import "../package/contents/ui/SensorConfig.js" as Sensors
import "../package/contents/ui/Probes.js" as Probes
import "../package/contents/ui/Sections.js" as Sections

Item {
    Ui.MonitorCore {
        id: core
        live: false
    }
    TestCase {
        name: "Sensors"
        function init() {
            core.cfg = {
                sections: "memory"
            };
            core.discoverSensors = false;
            core.powerSources = [];
            core.hardwareSensors = [];
            core._powerPrev = null;
        }
        function test_individualCoresFoldUnderOneReading() {
            const groups = core.parseHwSensorsJson(JSON.stringify({
                "coretemp-isa-0000": {
                    "Package id 0": {
                        temp1_input: 50,
                        temp1_crit: 100
                    },
                    "Core 0": {
                        temp2_input: 42
                    },
                    "Core 4": {
                        temp6_input: 46
                    }
                },
                "board-isa-0001": {
                    fan1: {
                        fan1_input: 0
                    },
                    "+12V": {
                        in0_input: 12.1
                    },
                    "Draw": {
                        power1_input: 8
                    }
                }
            }));
            core.applyHwSensorUpdate(groups);
            const list = core.sensorCatalog;
            compare(list.map(s => s.label), ["Package id 0", "Cores", "Core 0", "Core 4", "fan1", "+12V", "Draw"]);
            const cores = list[1];
            compare(cores.type, "cores");
            compare(cores.values, [42, 46]);
            compare(Sensors.reading(cores), "42–46°C");
            compare(list[5].unit, "V");
            compare(Sensors.reading(list[5]), "12.10 V");
            compare(list[4].value, 0, "a stopped fan is a reading");
            // Defaults: temperatures with cores as one row, and fans.
            compare(Sensors.rows(list, {}, "sensors").map(s => s.label), ["Package id 0", "Cores", "fan1"]);
            // The picker folds the cores under their Cores reading.
            const picker = Sensors.groups(list, [], {}, "");
            compare(picker.map(g => g.title), ["CPU (Intel)", "board-isa-0001"]);
            compare(picker[0].items.map(i => i.id), [list[0].id, cores.id]);
            compare(picker[0].items[1].members, [list[2].id, list[3].id]);
            compare(Sensors.groupIds(picker[0]).length, 4);
            // A filter matching one core keeps just it under Cores.
            const found = Sensors.groups(list, [], {}, "core 4");
            compare(found[0].items[0].members, [list[3].id]);
        }
        function test_selectionNamesAndMissingReadings() {
            core.applyHwSensorUpdate(core.parseHwSensorsJson('{"chip-0":{"temp1":{"temp1_input":40}}}'));
            const id = core.sensorCatalog[0].id;
            const cfg = {
                sensorSelection: Sensors.select("{}", "cpu", [id, "hw:gone:temp1"]),
                sensorNames: Sensors.rename("{}", id, "  Die  ")
            };
            const rows = Sensors.rows(core.sensorCatalog, cfg, "cpu");
            compare(rows.length, 1, "an undetected reading is left out of the card");
            compare(rows[0].label, "Die");
            compare(rows[0].original, "temp1");
            const picker = Sensors.groups(core.sensorCatalog, Sensors.ids(core.sensorCatalog, cfg.sensorSelection, "cpu"), Sensors.object(cfg.sensorNames), "");
            compare(picker[picker.length - 1].key, "missing", "but stays in the picker for removal");
            compare(Sensors.rename(cfg.sensorNames, id, " "), "{}");
            compare(Sensors.toggle(["a", "b"], ["b", "c"], true), ["a", "b", "c"]);
            compare(Sensors.toggle(["a", "b", "c"], ["a", "c"], false), ["b"]);
            compare(Sensors.selection(Sensors.select(cfg.sensorSelection, "cpu", null), "cpu"), null);
            compare(Sensors.selection("invalid", "cpu"), null);
            compare(Sensors.selection('{"cpu":false}', "cpu"), null);
            compare(Sensors.selection('{"cpu":["a","a",2]}', "cpu"), ["a"]);
        }
        function test_powerPollingWithoutPowerSection() {
            verify(!core.readPowerSensors);
            core.cfg = {
                sections: "cpu"
            };
            verify(!core.readPowerSensors, "CPU shows no extra readings by default");
            core.cfg = {
                sections: "cpu",
                sensorSelection: '{"cpu":["cpu:power"]}'
            };
            verify(core.readPowerSensors);
            verify(!core.showPowerSection);
            compare(Sensors.rows(core.sensorCatalog, core.cfg, "cpu").length, 0);
            core.applyPower(Probes.parsePower("rapl intel-rapl:0 1000000 90000000 package-0"), 1000);
            compare(Sensors.rows(core.sensorCatalog, core.cfg, "cpu").length, 0, "first counter has no rate");
            core.applyPower(Probes.parsePower("rapl intel-rapl:0 11000000 90000000 package-0"), 3000);
            compare(Sensors.rows(core.sensorCatalog, core.cfg, "cpu")[0].value, 5);
            core.applyPower(Probes.parsePower(""), 5000);
            compare(Sensors.rows(core.sensorCatalog, core.cfg, "cpu").length, 0, "failed probe clears old watts");
        }
        function test_probesFollowTheChosenReadings() {
            compare(Sensors.needs("{}", ["sensors"]), {
                hardware: true,
                power: false,
                nvidia: false
            });
            compare(Sensors.needs("{}", ["gpu"]), {
                hardware: false,
                power: true,
                nvidia: true
            });
            core.cfg = {
                sections: "gpu",
                sensorSelection: '{"gpu":["hw:chip:temp1"]}'
            };
            verify(core.readHardwareSensors);
            verify(!core.readPowerSensors);
            core.cfg = {
                sections: "sensors",
                sensorSelection: '{"sensors":["cpu:power"]}'
            };
            verify(core.readPowerSensors);
            core.cfg = {
                sections: "memory",
                sensorSelection: '{"cpu":["hw:chip:temp1"]}'
            };
            verify(!core.readHardwareSensors, "hidden destination does not poll");
            core.discoverSensors = true;
            verify(core.readHardwareSensors && core.readPowerSensors);
        }
        function test_cpuPowerExcludesPlatformAndGpuAndDuplicates() {
            const prev = Probes.parsePower("rapl intel-rapl:0 0 90000000 package-0\nrapl intel-rapl:1 0 90000000 package-1\nrapl intel-rapl:2 0 90000000 psys");
            const next = Probes.parsePower("rapl intel-rapl:0 10000000 90000000 package-0\nrapl intel-rapl:1 20000000 90000000 package-1\nrapl intel-rapl:2 80000000 90000000 psys\nhwmon hwmon1 10000000 zenpower\nhwmon hwmon2 30000000 amdgpu");
            const catalog = Sensors.catalog([], Probes.powerSources(prev, next, 2).list);
            const cpu = {
                sensorSelection: '{"cpu":["cpu:power"]}'
            };
            compare(Sensors.rows(catalog, {}, "cpu"), [], "nothing extra by default");
            compare(Sensors.rows(catalog, cpu, "cpu")[0].value, 15);
            compare(Sensors.rows(catalog, {}, "gpu")[0].value, 30);
            compare(Sensors.rows(catalog, {}, "power").length, 5, "the CPU total is not a source of its own");
            const zero = Sensors.catalog([], Probes.powerSources(null, Probes.parsePower("hwmon hwmon1 0 zenpower"), 0).list);
            compare(Sensors.rows(zero, cpu, "cpu")[0].value, 0, "zero is a valid measurement");
            compare(Sensors.reading({
                value: 0.25,
                unit: "W"
            }), "250 mW");
        }
        function test_positionValidation() {
            compare(Sections.positions("broken"), {});
            compare(Sections.positions('{"cpu":{"x":-20,"y":35.4,"width":2},"invalid":{"x":50}}'), {
                cpu: {
                    x: 0,
                    y: 35,
                    width: 180
                }
            });
            compare(Sections.positions(Sections.position('{"gpu":{"x":500}}', "cpu", {
                x: 100
            })), {
                gpu: {
                    x: 500
                },
                cpu: {
                    x: 100
                }
            });
        }
    }
}
