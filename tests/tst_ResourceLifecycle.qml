import QtQuick
import QtTest
import "../package/contents/ui" as Ui
import "../package/contents/ui/network" as Network

Item {
    id: root
    property int requests: 0
    property var sources: []

    Component {
        id: runner
        Item {
            property var connectedSources: []
            signal newData(string source, var data)
            Component.onCompleted: root.sources = root.sources.concat([this])
            function connectSource(command) {
                ++root.requests;
                connectedSources = connectedSources.concat([command]);
            }
            function disconnectSource(command) {
                connectedSources = connectedSources.filter(c => c !== command);
            }
        }
    }
    Component {
        id: probeComponent
        Ui.ShellProbe {
            sourceComponent: runner
            command: "echo sample"
            interval: 100000
        }
    }
    Component {
        id: coreComponent
        Ui.MonitorCore {
            live: false
            commandSourceComponent: runner
            cfg: ({
                    sections: "ping,cpu,memory,network,disk,gpu,custom,system",
                    updateInterval: 250,
                    pingInterval: 1,
                    currentTargetIndex: 0,
                    customCmd: "echo 1",
                    customCmdInterval: 1,
                    netShowInfo: true,
                    osUseFetch: true
                })
        }
    }
    Component {
        id: networkComponent
        Network.NetworkMonitor {
            commandSourceComponent: runner
        }
    }

    TestCase {
        name: "ResourceLifecycle"

        function init() {
            root.requests = 0;
            root.sources = [];
        }
        function outstanding() {
            return root.sources.reduce((n, s) => n + s.connectedSources.length, 0);
        }
        function test_probeStopsAndRestartsWithoutKeepingCommands() {
            const probe = createTemporaryObject(probeComponent, root);
            probe.running = true;
            tryCompare(probe, "busy", true);
            compare(outstanding(), 1);
            probe.running = false;
            compare(probe.busy, false);
            compare(outstanding(), 0);
            probe.running = true;
            tryCompare(probe, "busy", true);
            compare(root.requests, 2);
            probe.remote = "another-host";
            compare(outstanding(), 0);
            compare(probe.busy, false);
            probe.poll();
            compare(outstanding(), 1);
            probe.command = "";
            compare(outstanding(), 0);
            compare(probe.busy, false);
        }
        function test_probeTimeoutReplacesOneRequest() {
            const probe = createTemporaryObject(probeComponent, root);
            probe.poll();
            for (let i = 0; i < 100; i++) {
                probe._sentAt = Date.now() - probe.interval * 5;
                probe.poll();
                compare(outstanding(), 1);
            }
            compare(root.requests, 101);
        }
        function test_probeWithoutRunnerDoesNotBecomeBusy() {
            const probe = createTemporaryObject(probeComponent, root, {
                sourceComponent: null
            });
            probe.poll();
            compare(probe.busy, false);
            probe.sourceComponent = runner;
            probe.poll();
            compare(probe.busy, true);
            compare(outstanding(), 1);
        }
        function test_demoCoreDoesNotPoll() {
            const core = createTemporaryObject(coreComponent, root);
            core.activeIface = "eth0";
            core.gpuMode = "nvidia";
            core.triggerPing();
            wait(1100);
            compare(root.requests, 0);
            compare(core._sysTick, 0, "demo cores must not wake the system poll timer");
            compare(core.isPinging, false);
        }
        function test_tabAddressesFollowOpenTabs() {
            const net = createTemporaryObject(networkComponent, root);
            for (let i = 0; i < 1000; i++) {
                const host = "tab" + i + ".example";
                net.tabAddresses = Object.assign({}, net.tabAddresses, {
                    [host]: ["192.0.2.1"]
                });
                net.updateTabs([
                    {
                        host: host,
                        title: host,
                        browser: "Firefox"
                    }
                ]);
                compare(Object.keys(net.tabAddresses), [host]);
            }
            net.updateTabs([]);
            compare(Object.keys(net.tabAddresses).length, 0);
            net.updateTabs([
                {
                    host: "late.example",
                    title: "Late",
                    browser: "Firefox"
                }
            ]);
            const forward = root.sources.find(s => s.connectedSources.length);
            verify(forward !== undefined);
            const command = forward.connectedSources[0];
            net.updateTabs([]);
            forward.newData(command, {
                stdout: "addr\tlate.example\t192.0.2.1\n"
            });
            compare(Object.keys(net.tabAddresses).length, 0, "late replies cannot restore closed tabs");
        }
        function test_disablingTabsReleasesLookups() {
            const net = createTemporaryObject(networkComponent, root);
            net.updateTabs([
                {
                    host: "open.example",
                    title: "Open",
                    browser: "Firefox"
                }
            ]);
            compare(outstanding(), 1);
            net.tabAddresses = {
                "old.example": ["192.0.2.1"]
            };
            net.tabsEnabled = false;
            compare(outstanding(), 0);
            compare(net.tabs.length, 0);
            compare(Object.keys(net.tabAddresses).length, 0);
        }
        function test_extraLookupsStayBoundedAndUnique() {
            const net = createTemporaryObject(networkComponent, root);
            for (let i = 0; i < 1000; i++)
                net.resolveIps(["192.0." + Math.floor(i / 256) + "." + (i % 256), "192.0.2.1"]);
            verify(net._extraIps.length <= 256);
            compare(new Set(net._extraIps).size, net._extraIps.length);
            compare(outstanding(), 1);
        }
    }
}
