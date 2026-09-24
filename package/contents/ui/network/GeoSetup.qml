import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../Probes.js" as Probes
import "../OsFetch.js" as OsFetch
import ".." as Ui

// Countries and owners need two things on this machine: mmdblookup and a
// .mmdb database. This shows what is there, installs db-ip's free Lite
// databases on a click (Glassy downloads only here and, when switched on,
// the Threats page's blocklists), and says how to get mmdblookup on each
// distribution and on NixOS.
NetDialog {
    id: setup
    property var status: null
    property string result: ""
    property bool downloading: false
    readonly property bool dbAged: !!status && status.countryTime > 0 && Date.now() - status.countryTime > 40 * 86400000

    function check() {
        source.connectSource(OsFetch.shellCmd(Probes.GEO_STATUS_CMD));
    }
    function download() {
        downloading = true;
        result = "Downloading…";
        source.connectSource(OsFetch.shellCmd(Probes.GEO_DOWNLOAD_CMD));
    }

    padding: 22
    width: Math.min(620, page.width - 40)
    onOpened: check()

    component Line: RowLayout {
        id: line
        property bool ok: false
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: 10
        Text {
            text: line.ok ? "✓" : "✕"
            color: line.ok ? setup.theme.ok : setup.theme.warn
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Text {
            Layout.preferredWidth: 130
            text: line.label
            color: setup.theme.text
            font.family: setup.theme.fontFamily
            font.pixelSize: 12
        }
        Text {
            Layout.fillWidth: true
            text: line.value
            color: setup.theme.muted
            font.family: "monospace"
            font.pixelSize: 10
            elide: Text.ElideMiddle
        }
    }
    component Cmd: Rectangle {
        id: cmd
        property string label: ""
        property string command: ""
        Layout.fillWidth: true
        implicitHeight: 30
        radius: 7
        color: setup.theme.sunk
        border.color: setup.theme.line2
        Text {
            x: 10
            width: 110
            anchors.verticalCenter: parent.verticalCenter
            text: cmd.label
            color: setup.theme.dim
            font.family: setup.theme.fontFamily
            font.pixelSize: 10
        }
        Text {
            x: 120
            width: parent.width - 170
            anchors.verticalCenter: parent.verticalCenter
            text: cmd.command
            color: setup.theme.text
            font.family: "monospace"
            font.pixelSize: 10
            elide: Text.ElideRight
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "copy"
            color: copyArea.containsMouse ? setup.theme.brand : setup.theme.dim
            font.family: setup.theme.fontFamily
            font.pixelSize: 10
            MouseArea {
                id: copyArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: setup.page.copy(cmd.command)
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 10
        Text {
            text: "Countries and owners"
            color: setup.theme.text
            font.family: setup.theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Glassy looks addresses up in a database on this machine: nothing is sent anywhere. It needs mmdblookup and a country (and optionally an ASN) database in the .mmdb format."
            color: setup.theme.muted
            font.family: setup.theme.fontFamily
            font.pixelSize: 11
        }
        Line {
            ok: !!setup.status && setup.status.mmdblookup !== ""
            label: "mmdblookup"
            value: !setup.status ? "checking…" : setup.status.mmdblookup || "not installed (see below)"
        }
        Line {
            ok: !!setup.status && setup.status.country !== ""
            label: "Country database"
            value: !setup.status ? "" : setup.status.country ? setup.status.country + (setup.status.countryTime ? "  · " + Qt.formatDate(new Date(setup.status.countryTime), "yyyy-MM-dd") : "") : "none found"
        }
        Line {
            ok: !!setup.status && setup.status.asn !== ""
            label: "Owner (ASN) database"
            value: !setup.status ? "" : setup.status.asn || "none found (optional)"
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 10
            NetButton {
                theme: setup.theme
                primary: true
                enabled: !setup.downloading && !!setup.status && setup.status.fetch !== ""
                text: setup.status && setup.status.country.indexOf("/.local/share/GeoIP/") !== -1 ? (setup.dbAged ? "Update db-ip Lite" : "Download again") : "Download db-ip Lite"
                tooltip: "Free country + ASN databases by db-ip.com (CC BY 4.0), about 17 MB, into ~/.local/share/GeoIP. They are updated monthly."
                onClicked: setup.download()
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: setup.result !== "" ? setup.result : setup.status && setup.status.fetch === "" ? "Needs curl or wget." : "Into ~/.local/share/GeoIP · by db-ip.com, CC BY 4.0"
                color: setup.theme.dim
                font.family: setup.theme.fontFamily
                font.pixelSize: 10
            }
        }

        Text {
            Layout.topMargin: 8
            text: "mmdblookup"
            color: setup.theme.muted
            font.family: setup.theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
        Cmd {
            label: "Arch"
            command: "sudo pacman -S libmaxminddb"
        }
        Cmd {
            label: "Debian / Ubuntu"
            command: "sudo apt install mmdb-bin"
        }
        Cmd {
            label: "Fedora"
            command: "sudo dnf install libmaxminddb"
        }
        Cmd {
            label: "NixOS (flake)"
            command: "programs.glassy-system-monitor = { enable = true; geoip = true; };"
        }
        Cmd {
            label: "NixOS (plain)"
            command: "environment.systemPackages = with pkgs; [ libmaxminddb dbip-country-lite dbip-asn-lite ];"
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "On NixOS the flake module installs mmdblookup and nixpkgs' db-ip databases and points Glassy at them; no download needed. MaxMind GeoLite2 files in /usr/share/GeoIP work too."
            color: setup.theme.dim
            font.family: setup.theme.fontFamily
            font.pixelSize: 10
        }
        NetButton {
            Layout.alignment: Qt.AlignRight
            theme: setup.theme
            text: "Close"
            onClicked: setup.close()
        }
    }

    Ui.CommandSource {
        id: source
        sourceComponent: setup.page.service.commandSourceComponent
        onNewData: function (sourceName, data) {
            source.disconnectSource(sourceName);
            const out = String(data["stdout"] || "");
            if (out.indexOf("mm ") === 0 || out.indexOf("\nmm ") !== -1) {
                setup.status = Probes.parseGeoStatus(out);
                return;
            }
            setup.downloading = false;
            const failed = out.indexOf("failed") !== -1 || out.trim() === "";
            setup.result = failed ? "The download did not work (offline?). " + out.trim().replace(/\n/g, " · ") : "Installed: " + out.trim().replace(/\n/g, " · ") + ". Countries appear as addresses resolve.";
            // Look addresses up again, now with the database.
            setup.page.net.hosts = {};
            setup.check();
        }
    }
}
