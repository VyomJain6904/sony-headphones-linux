import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property var status: ({})
    property bool daemonReachable: false
    readonly property bool connected: status.connected === true
    property string actionError: ""

    function readStatus() {
        // Reads via `sony-headphonesctl status` rather than XHR-ing
        // status.json directly - Qt6 disables local-file XMLHttpRequest
        // reads by default, which made this always fail.
        statusExec.connectSource("sony-headphonesctl status")
    }

    Plasma5Support.DataSource {
        id: statusExec
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)
            if (data["exit code"] === 0 && data["stdout"]) {
                try {
                    root.status = JSON.parse(data["stdout"])
                    root.daemonReachable = true
                } catch (e) {
                    root.daemonReachable = false
                }
            } else {
                root.daemonReachable = false
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.readStatus()
    }

    Timer {
        id: postCommandRefresh
        interval: 300
        onTriggered: root.readStatus()
    }

    Plasma5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)
            root.actionError = (data["exit code"] !== 0 && data["stderr"]) ? String(data["stderr"]).trim() : ""
            postCommandRefresh.restart()
        }
    }

    function run(args) {
        exec.connectSource("sony-headphonesctl " + args)
    }

    function setNoiseMode(mode) { root.run("noise " + mode) }
    function setAmbientLevel(level) { root.run("ambient-level " + Math.round(level)) }
    function setFocusOnVoice(on) { root.run("focus-on-voice " + (on ? "on" : "off")) }
    function setSpeakToChat(on) { root.run("speak-to-chat " + (on ? "on" : "off")) }
    function setDsee(on) { root.run("dsee " + (on ? "on" : "off")) }
    function setEqualizerPreset(preset) { root.run("eq-preset " + preset) }
    function setConnectionPriority(priority) { root.run("connection " + priority) }
    function setVolume(volume) { root.run("volume " + Math.round(volume)) }
    function refresh() { root.run("refresh") }
    function setPanelOpen(open) { root.run(open ? "panel-open" : "panel-close") }

    Component.onCompleted: root.readStatus()
    onExpandedChanged: root.setPanelOpen(root.expanded)

    preferredRepresentation: compactRepresentation

    compactRepresentation: MouseArea {
        id: compactRoot
        Layout.minimumWidth: Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.fill: parent
            source: "audio-headphones"
            active: compactRoot.containsMouse
        }
    }

    fullRepresentation: Loader {
        source: "FullRepresentation.qml"
        onLoaded: item.backend = root
    }
}
