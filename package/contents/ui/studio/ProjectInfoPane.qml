import QtQuick
import "Theme.js" as Theme
import "ProjectInfo.js" as Project

Column {
    id: info
    required property var studio
    property var counts: ({})
    property var contributorList: []
    property var requests: []
    property bool requested: false
    readonly property string currentVersion: Project.currentVersion
    property string latestVersion: ""
    property string releaseCheckState: "Not checked"
    readonly property string versionStatus: latestVersion ? Project.releaseStatus(currentVersion, latestVersion) : releaseCheckState

    function checkRelease() {
        if (!onlineEnabled || releaseCheckState === "Checking…")
            return;
        latestVersion = "";
        releaseCheckState = "Checking…";
        const request = new XMLHttpRequest();
        requests.push(request);
        request.open("GET", Project.latestReleaseUrl);
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE)
                return;
            info.latestVersion = request.status === 200 ? Project.releaseVersion(request.responseText) : "";
            info.releaseCheckState = info.latestVersion ? "Checked" : "Could not check for updates";
        };
        request.send();
        timeout.restart();
    }
    readonly property bool onlineEnabled: studio.onScreen
    spacing: 16

    function loadCounts() {
        if (!onlineEnabled || requested)
            return;
        requested = true;
        checkRelease();
        Project.statistics.forEach(function (stat) {
            const request = new XMLHttpRequest();
            info.requests.push(request);
            request.open("GET", stat.url);
            request.onreadystatechange = function () {
                if (request.readyState !== XMLHttpRequest.DONE || request.status !== 200)
                    return;
                const value = Project.count(request.responseText);
                if (value) {
                    const next = Object.assign({}, info.counts);
                    next[stat.id] = value;
                    info.counts = next;
                }
            };
            request.send();
        });
        const contributorsRequest = new XMLHttpRequest();
        requests.push(contributorsRequest);
        contributorsRequest.open("GET", Project.contributorsUrl);
        contributorsRequest.onreadystatechange = function () {
            if (contributorsRequest.readyState === XMLHttpRequest.DONE && contributorsRequest.status === 200)
                info.contributorList = Project.contributors(contributorsRequest.responseText);
        };
        contributorsRequest.send();
        timeout.restart();
    }
    function cancelRequests() {
        requests.forEach(function (request) {
            request.onreadystatechange = null;
            request.abort();
        });
        requests = [];
        if (releaseCheckState === "Checking…")
            releaseCheckState = "Could not check for updates";
    }
    onOnlineEnabledChanged: if (onlineEnabled)
        loadCounts()
    Component.onCompleted: loadCounts()
    Component.onDestruction: cancelRequests()
    Timer {
        id: timeout
        interval: 8000
        onTriggered: info.cancelRequests()
    }

    Row {
        width: parent.width
        spacing: 14
        Image {
            width: 64
            height: 64
            source: Qt.resolvedUrl("../../../icon.png")
            sourceSize.width: 128
            sourceSize.height: 128
            fillMode: Image.PreserveAspectFit
            Accessible.name: "Glassy System Monitor project icon"
        }
        Column {
            width: parent.width - 78
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7
            Text {
                width: parent.width
                text: Project.name
                wrapMode: Text.WordWrap
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Row {
                spacing: 7
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: Theme.sunk
                    Text {
                        objectName: "authorAvatarFallback"
                        anchors.centerIn: parent
                        text: "M"
                        color: Theme.brand
                        font.pixelSize: 12
                        visible: !avatar.ready
                    }
                    Avatar {
                        id: avatar
                        objectName: "authorAvatar"
                        anchors.fill: parent
                        source: info.onlineEnabled ? Project.avatar : ""
                        radius: 12
                        Accessible.name: Project.author + " GitHub avatar"
                    }
                }
                StudioButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "By " + Project.author + " ↗"
                    compact: true
                    onClicked: Qt.openUrlExternally(Project.profile)
                }
            }
        }
    }
    Text {
        width: parent.width
        text: "An open-source system monitor for Plasma and Hyprland: CPU, memory, network, ping, disks, GPU, sensors and power in one glass card. Explore the project, get updates, or help improve it."
        wrapMode: Text.WordWrap
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
    Rectangle {
        objectName: "projectVersion"
        width: parent.width
        height: versionContent.implicitHeight + 26
        radius: 10
        color: Theme.sunk
        border.color: Theme.line2
        Column {
            id: versionContent
            x: 13
            y: 13
            width: parent.width - 26
            spacing: 8
            Text {
                text: "Installed version · " + info.currentVersion
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            Text {
                objectName: "latestVersionLabel"
                text: "Latest stable release · " + (info.latestVersion || "—")
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
            Text {
                objectName: "versionStatusLabel"
                width: parent.width
                text: info.versionStatus
                wrapMode: Text.WordWrap
                color: text === "Update available" ? Theme.brand : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
            Flow {
                width: parent.width
                spacing: 8
                StudioButton {
                    text: info.versionStatus === "Update available" ? "Get update ↗" : "View latest release ↗"
                    compact: true
                    onClicked: Qt.openUrlExternally(Project.releasesPage)
                }
                StudioButton {
                    text: "Check again"
                    compact: true
                    enabled: info.onlineEnabled && info.releaseCheckState !== "Checking…"
                    onClicked: info.checkRelease()
                }
            }
        }
    }
    Flow {
        width: parent.width
        spacing: 8
        Repeater {
            model: Project.statistics
            Rectangle {
                required property var modelData
                objectName: "stat_" + modelData.id
                width: info.width >= 570 ? (info.width - 16) / 3 : info.width >= 360 ? (info.width - 8) / 2 : info.width
                height: 82
                radius: 10
                color: statArea.containsMouse ? Theme.hover : Theme.sunk
                border.width: 1
                border.color: statArea.containsMouse ? Theme.brand : Theme.line2
                Image {
                    objectName: "statIcon_" + parent.modelData.id
                    x: 12
                    y: 12
                    width: 22
                    height: 22
                    source: Qt.resolvedUrl("icons/" + parent.modelData.icon)
                    sourceSize: Qt.size(44, 44)
                }
                Text {
                    x: 43
                    y: 8
                    text: info.counts[parent.modelData.id] || "—"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 21
                    font.weight: Font.DemiBold
                }
                Text {
                    x: 12
                    y: 48
                    width: parent.width - 30
                    text: parent.modelData.label + " ↗"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: statArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.name: parent.modelData.label + ", open " + parent.modelData.href
                    onClicked: Qt.openUrlExternally(parent.modelData.href)
                }
            }
        }
    }
    Rectangle {
        objectName: "projectLicense"
        width: parent.width
        height: 64
        radius: 10
        color: Theme.sunk
        border.color: Theme.line2
        border.width: 1
        Column {
            x: 13
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                text: "License · " + Project.license
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            Text {
                text: Project.licenseId + " · From the bundled LICENSE file"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }
    }
    Column {
        objectName: "contributorsSection"
        width: parent.width
        visible: info.contributorList.length > 0
        spacing: 8
        Row {
            width: parent.width
            spacing: 10
            Text {
                text: "Contributors"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            StudioButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "See all on GitHub ↗"
                compact: true
                onClicked: Qt.openUrlExternally(Project.contributorsPage)
            }
        }
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: info.contributorList
                Rectangle {
                    id: contributorCard
                    required property var modelData
                    objectName: "contributor_" + modelData.login
                    width: info.width >= 570 ? (info.width - 16) / 3 : info.width >= 360 ? (info.width - 8) / 2 : info.width
                    height: 58
                    radius: 10
                    color: contributorArea.containsMouse ? Theme.hover : Theme.sunk
                    border.color: contributorArea.containsMouse ? Theme.brand : Theme.line2
                    border.width: 1
                    Rectangle {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34
                        radius: 17
                        color: Theme.panelTop
                        Text {
                            anchors.centerIn: parent
                            text: contributorCard.modelData.login[0].toUpperCase()
                            color: Theme.brand
                            font.pixelSize: 13
                            visible: !contributorAvatar.ready
                        }
                        Avatar {
                            id: contributorAvatar
                            anchors.fill: parent
                            source: info.onlineEnabled ? contributorCard.modelData.avatar : ""
                            radius: 17
                            Accessible.name: contributorCard.modelData.login + " avatar"
                        }
                    }
                    Column {
                        x: 52
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 62
                        spacing: 2
                        Text {
                            width: parent.width
                            text: contributorCard.modelData.login
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: contributorCard.modelData.commits + (contributorCard.modelData.commits === 1 ? " commit" : " commits")
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        id: contributorArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.name: "Open " + contributorCard.modelData.login + " on GitHub"
                        onClicked: Qt.openUrlExternally(contributorCard.modelData.profile)
                    }
                }
            }
        }
    }
    Column {
        width: parent.width
        spacing: 8
        Text {
            text: "Support the project"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: Project.funding
                Rectangle {
                    required property var modelData
                    objectName: "funding_" + modelData.id
                    width: info.width >= 570 ? (info.width - 16) / 3 : info.width >= 360 ? (info.width - 8) / 2 : info.width
                    height: 64
                    radius: 10
                    color: linkArea.containsMouse ? Theme.hover : Theme.sunk
                    border.width: 1
                    border.color: linkArea.containsMouse ? Theme.brand : Theme.line2
                    Image {
                        objectName: "fundingIcon_" + parent.modelData.id
                        x: 13
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        source: Qt.resolvedUrl("icons/" + parent.modelData.icon)
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(52, 52)
                    }
                    Text {
                        x: 49
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 67
                        text: parent.modelData.label
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: linkArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.name: "Support on " + parent.modelData.label
                        onClicked: Qt.openUrlExternally(parent.modelData.url)
                    }
                }
            }
        }
    }
    Flow {
        width: parent.width
        spacing: 8
        StudioButton {
            text: "View source on GitHub ↗"
            compact: true
            onClicked: Qt.openUrlExternally(Project.repository)
        }
        StudioButton {
            text: "Report an issue ↗"
            compact: true
            onClicked: Qt.openUrlExternally(Project.repository + "/issues")
        }
    }
}
