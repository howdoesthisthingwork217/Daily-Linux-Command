import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property string cmdName: ""
    property string cmdDesc: ""
    property string cmdSynopsis: ""
    property string cmdCategory: ""
    property string cmdDate: ""
    property bool manAvailable: true
    property bool loading: true
    property bool errored: false

    readonly property string serverUrl: "https://dailylinuxcommand.com/api/today"
    readonly property int refreshIntervalMs: 3600000  // 1 hour

    Plasmoid.title: cmdName ? ("$ " + cmdName) : "Command of the Day"

    function localDateStr() {
        var d = new Date()
        var y = d.getFullYear()
        var m = String(d.getMonth() + 1).padStart(2, "0")
        var day = String(d.getDate()).padStart(2, "0")
        return y + "-" + m + "-" + day
    }

    function fetchCommand() {
        loading = true
        errored = false
        var xhr = new XMLHttpRequest()

        watchdogTimer.stop()
        watchdogTimer.xhrRef = xhr
        watchdogTimer.start()

        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                watchdogTimer.stop()
                loading = false
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText)
                        cmdName = data.name || ""
                        cmdDesc = data.description || ""
                        cmdSynopsis = data.synopsis || ""
                        cmdCategory = data.category || ""
                        cmdDate = data.date || ""
                        manAvailable = !!data.man_available
                    } catch (e) {
                        errored = true
                    }
                } else {
                    errored = true
                }
            }
        }
        xhr.onerror = function () {
            watchdogTimer.stop()
            loading = false
            errored = true
        }
        try {
            var sep = serverUrl.indexOf("?") === -1 ? "?" : "&"
            xhr.open("GET", serverUrl + sep + "date=" + localDateStr())
            xhr.send()
        } catch (e) {
            loading = false
            errored = true
        }
    }

    // Some environments never fire onreadystatechange/onerror at all if the
    // request stalls at the connect stage. Without this, that leaves the
    // spinner running forever with no visible failure. 10s is generous for
    // a same-region HTTPS request; if it fires, abort and surface an error
    // instead of hanging indefinitely.
    Timer {
        id: watchdogTimer
        property var xhrRef: null
        interval: 10000
        repeat: false
        onTriggered: {
            if (xhrRef) {
                try { xhrRef.abort() } catch (e) {}
            }
            root.loading = false
            root.errored = true
        }
    }

    Component.onCompleted: fetchCommand()

    Timer {
        id: refreshTimer
        interval: refreshIntervalMs
        running: true
        repeat: true
        onTriggered: root.fetchCommand()
    }

    // Widget only needs a fresh pull once a day, but re-checking hourly is
    // cheap since the server caches the day's result itself.

    compactRepresentation: MouseArea {
        Layout.minimumWidth: label.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        onClicked: root.expanded = !root.expanded

        PlasmaComponents3.Label {
            id: label
            anchors.centerIn: parent
            text: root.errored ? "cotd: offline"
                  : root.loading ? "cotd: ..."
                  : "$ " + root.cmdName
            font.family: "monospace"
            elide: Text.ElideRight
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 12
        Layout.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: "Command of the Day"
                font.bold: true
                opacity: 0.7
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                Layout.fillWidth: true
            }
            PlasmaComponents3.Label {
                text: root.cmdDate
                opacity: 0.5
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
            }
        }

        PlasmaComponents3.BusyIndicator {
            visible: root.loading
            running: root.loading
            Layout.alignment: Qt.AlignHCenter
        }

        PlasmaComponents3.Label {
            visible: root.errored && !root.loading
            text: "Couldn't reach dailylinuxcommand.com."
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        ColumnLayout {
            visible: !root.loading && !root.errored
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: "$ man " + root.cmdName
                font.bold: true
                font.family: "monospace"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.5
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            PlasmaComponents3.Label {
                text: root.cmdCategory
                opacity: 0.6
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
            }

            PlasmaComponents3.Label {
                text: root.cmdDesc
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: synopsisLabel.implicitHeight + Kirigami.Units.smallSpacing * 2
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.disabledTextColor
                border.width: 1
                radius: 4

                PlasmaComponents3.Label {
                    id: synopsisLabel
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    text: "$ " + root.cmdSynopsis
                    font.family: "monospace"
                    color: Kirigami.Theme.positiveTextColor
                    wrapMode: Text.WordWrap
                }
            }

            PlasmaComponents3.Label {
                visible: !root.manAvailable
                text: "Full man page not installed on server for this command."
                opacity: 0.5
                font.italic: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        Item { Layout.fillHeight: true }

        PlasmaComponents3.Button {
            text: "Refresh"
            icon.name: "view-refresh"
            Layout.alignment: Qt.AlignRight
            onClicked: root.fetchCommand()
        }
    }
}

