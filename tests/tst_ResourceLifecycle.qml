import QtQuick
import QtTest
import "../package/contents/ui" as Ui
import "../package/contents/ui/network" as Network

Item {
    id: root
    property int requests: 0
    property var commands: []
    property var sources: []

    Component {
        id: runner
        Item {
            property var connectedSources: []
            signal newData(string source, var data)
            Component.onCompleted: root.sources = root.sources.concat([this])
            function connectSource(command) {
                ++root.requests;
                root.commands = root.commands.concat([command]);
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
    Component {
        id: networkServiceComponent
        Network.NetworkService {
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
        function notificationCommands() {
            return root.sources.reduce((commands, s) => commands.concat(s.connectedSources), []).filter(c => String(c).indexOf("notify-send") !== -1);
        }
        function test_kdeLinuxImageFallbackIsCached() {
            const core = createTemporaryObject(coreComponent, root, {
                live: true
            });
            verify(core !== null);
            const kde = "KDE Linux\n6.12\nkde-host\n1h\nkde\n\n\n\nkde-linux\n";
            const count = () => root.commands.filter(c => c.includes("hostnamectl")).length;
            const before = count();
            core.parseOsInfo("Fedora Linux\n6.12\nfedora\n1h\nfedora\n42\n\n\nfedora\n");
            compare(count(), before, "other distros never run hostnamectl");
            core.parseOsInfo(kde);
            compare(count(), before + 1);
            core.parseOsInfo(kde);
            compare(count(), before + 1, "do not start concurrent image probes");
            const source = root.sources.find(s => s.connectedSources.some(c => c.includes("hostnamectl")));
            verify(source);
            source.newData(source.connectedSources.find(c => c.includes("hostnamectl")), {
                stdout: "  OS Image: kde-linux\n  OS Image Version: 202609290254\n"
            });
            compare(core.osImageId, "kde-linux");
            compare(core.osImageVersion, "202609290254");
            core.parseOsInfo(kde);
            compare(core.osImageVersion, "202609290254", "ordinary refresh keeps the fallback");
            compare(count(), before + 1, "image metadata is not polled");
            verify(core.osInfoRows.some(r => r.lbl === "OS Image Version" && r.val === "202609290254"));

            core.cfg = Object.assign({}, core.cfg, {
                remoteHost: "other-host"
            });
            compare(core.osImageId, "");
            compare(core.osImageVersion, "");
            core.parseOsInfo("KDE Linux\n6.12\nkde-host\n1h\nkde\n\n202610010254\nkde-linux\nkde-linux\n");
            compare(count(), before + 1, "os-release already has both fields");
            compare(core.osImageVersion, "202610010254");
            core.parseOsInfo(kde);
            compare(count(), before + 2, "a new host gets its own fallback attempt");
            const failedSource = root.sources.find(s => s.connectedSources.some(c => c.includes("hostnamectl")));
            failedSource.newData(failedSource.connectedSources.find(c => c.includes("hostnamectl")), {
                stdout: ""
            });
            core.parseOsInfo(kde);
            compare(count(), before + 2, "missing/failed hostnamectl is not retried every refresh");
        }

        function test_networkAlertsRequireExplicitOptIn() {
            const service = createTemporaryObject(networkServiceComponent, root);
            verify(service !== null);
            compare(service.alertSettings.newApp, false);
            compare(service.alertSettings.notify, false);
            service.alert("newApp", "New app online", "Example connection");
            compare(service.alertLog.length, 0);
            compare(notificationCommands().length, 0);

            service.state = {
                alerts: {
                    newApp: true
                }
            };
            service.alert("newApp", "New app online", "Example connection");
            compare(service.alertLog.length, 1);
            compare(notificationCommands().length, 0);

            service.state = {
                alerts: {
                    newApp: true,
                    notify: true
                }
            };
            service.alert("newApp", "New app online", "Example connection");
            compare(service.alertLog.length, 2);
            compare(notificationCommands().length, 1);
        }
        function test_networkCollectionFollowsVisibleFeatures() {
            const service = createTemporaryObject(networkServiceComponent, root);
            verify(service !== null);
            compare(service.collectingEnabled, false);
            compare(service.monitor.running, false);

            service.featureActive = true;
            service.recording = true;
            compare(service.historyActive, true);
            compare(service.monitor.running, true);
            service.featureActive = false;
            compare(service.historyActive, false);
            compare(service.recording, false);
            compare(service.monitor.running, false);

            service.windowOpen = true;
            compare(service.monitor.running, true);
            service.windowOpen = false;
            compare(service.monitor.running, false);

            service.pillActive = true;
            compare(service.monitor.running, true);
            compare(service.historyActive, false);
            service.pillActive = false;
            compare(service.monitor.running, false);
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
