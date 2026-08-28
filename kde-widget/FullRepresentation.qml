import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

PlasmaExtras.Representation {
    id: fullRoot

    property var backend: null
    readonly property var status: backend ? backend.status : ({})
    readonly property var capabilities: status.capabilities || {}
    readonly property var device: status.device || {}
    readonly property var battery: status.battery || {}
    readonly property var noise: status.noise || {}
    readonly property var speakToChat: status.speak_to_chat || {}
    readonly property var equalizer: status.equalizer || {}
    readonly property var playback: status.playback || {}
    readonly property var connectionInfo: status.connection || {}
    readonly property bool connected: status.connected === true

    // Let Plasma size the representation normally, with a sensible maximum.
    Layout.preferredWidth: Kirigami.Units.gridUnit * 20
    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.preferredHeight: Kirigami.Units.gridUnit * 48
    Layout.maximumHeight: Kirigami.Units.gridUnit * 48

    onBackendChanged: {
        if (backend)
            backend.refresh()
    }

    function phaseLabel(phase) {
        switch (phase) {
        case "idle": return "Idle"
        case "connecting": return "Connecting…"
        case "syncing": return "Syncing…"
        case "ready": return "Connected"
        case "error": return "Error"
        default: return phase || "Unknown"
        }
    }

    function codecLabel(codec) {
        if (!codec || codec === "unknown")
            return ""
        return codec.toUpperCase()
    }

    function metaText() {
        if (!fullRoot.backend || !fullRoot.backend.daemonReachable)
            return "Service unavailable"

        var text = fullRoot.phaseLabel(fullRoot.status.phase)

        if (fullRoot.connected) {
            var detail = fullRoot.codecLabel(fullRoot.device.codec)

            if (fullRoot.device.firmware)
                detail += (detail ? " · " : "") + "firmware " + fullRoot.device.firmware

            if (detail)
                text += " · " + detail
        }

        return text
    }

    function presetLabel(preset) {
        if (!preset)
            return ""

        return preset.split("_").map(function(w) {
            return w.charAt(0).toUpperCase() + w.slice(1)
        }).join(" ")
    }

    function batteryRows() {
        var rows = []
        var b = fullRoot.battery

        if (b.main && b.main.present)
            rows.push({
                label: "Battery",
                level: b.main.level,
                charging: b.main.charging
            })

        if (b.left && b.left.present)
            rows.push({
                label: "Left",
                level: b.left.level,
                charging: b.left.charging
            })

        if (b.right && b.right.present)
            rows.push({
                label: "Right",
                level: b.right.level,
                charging: b.right.charging
            })

        if (b["case"] && b["case"].present)
            rows.push({
                label: "Case",
                level: b["case"].level,
                charging: b["case"].charging
            })

        return rows
    }

    contentItem: QQC2.ScrollView {
        id: scrollView

        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

        ColumnLayout {
            id: content

            width: scrollView.availableWidth
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "audio-headphones"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    Kirigami.Heading {
                        level: 3
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: fullRoot.device.name || "Sony Headphones"
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        opacity: 0.7
                        text: fullRoot.metaText()
                    }
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                visible: text.length > 0
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.negativeTextColor
                text: (fullRoot.backend && fullRoot.backend.actionError)
                    ? fullRoot.backend.actionError
                    : (fullRoot.status.last_error || "")
            }

            SectionTitle {
                text: "BATTERY"
                visible: batteryRepeater.count > 0
            }

            Repeater {
                id: batteryRepeater

                model: fullRoot.batteryRows()

                delegate: BatteryRow {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    Layout.rightMargin: Kirigami.Units.smallSpacing

                    label: modelData.label
                    level: modelData.level
                    charging: modelData.charging
                }
            }

            SectionTitle {
                text: "SOUND CONTROL"

                visible: fullRoot.connected &&
                         (fullRoot.capabilities.noise_cancelling ||
                          fullRoot.capabilities.ambient_sound)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter

                visible: fullRoot.connected &&
                         (fullRoot.capabilities.noise_cancelling ||
                          fullRoot.capabilities.ambient_sound)

                spacing: Kirigami.Units.smallSpacing

                PC3.Button {
                    visible: fullRoot.capabilities.noise_cancelling
                    text: "Noise cancelling"
                    checkable: true
                    checked: fullRoot.noise.mode === "anc"

                    onClicked: fullRoot.backend.setNoiseMode("anc")
                }

                PC3.Button {
                    visible: fullRoot.capabilities.ambient_sound
                    text: "Ambient"
                    checkable: true
                    checked: fullRoot.noise.mode === "ambient"

                    onClicked: fullRoot.backend.setNoiseMode("ambient")
                }

                PC3.Button {
                    text: "Off"
                    checkable: true
                    checked: fullRoot.noise.mode === "off"

                    onClicked: fullRoot.backend.setNoiseMode("off")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                visible: fullRoot.connected &&
                         fullRoot.capabilities.ambient_sound

                spacing: 2

                RowLayout {
                    Layout.fillWidth: true

                    QQC2.Label {
                        text: "Ambient level"
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    QQC2.Label {
                        opacity: 0.7
                        text: Math.round(ambientSlider.value)
                    }
                }

                PC3.Slider {
                    id: ambientSlider

                    Layout.fillWidth: true

                    from: 1
                    to: 20
                    stepSize: 1

                    value: fullRoot.noise.ambient_level || 1

                    onMoved: fullRoot.backend.setAmbientLevel(value)
                }
            }

            ToggleRow {
                id: focusToggle

                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                visible: fullRoot.connected &&
                         fullRoot.capabilities.ambient_sound

                label: "Focus on voice"
                caption: "Prioritize voices in ambient mode"
                checked: fullRoot.noise.focus_on_voice === true

                onTriggered:
                    fullRoot.backend.setFocusOnVoice(!focusToggle.checked)
            }

            ToggleRow {
                id: speakToggle

                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                visible: fullRoot.connected &&
                         fullRoot.capabilities.speak_to_chat

                label: "Speak-to-Chat"
                caption: "Pause or lower audio when you speak"
                checked: fullRoot.speakToChat.enabled === true

                onTriggered:
                    fullRoot.backend.setSpeakToChat(!speakToggle.checked)
            }

            SectionTitle {
                text: "SOUND"

                visible: fullRoot.connected &&
                         ((fullRoot.equalizer.available_presets &&
                           fullRoot.equalizer.available_presets.length > 0) ||
                          fullRoot.capabilities.dsee)
            }

            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                visible: fullRoot.connected &&
                         fullRoot.equalizer.available_presets &&
                         fullRoot.equalizer.available_presets.length > 0

                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: fullRoot.equalizer.available_presets || []

                    delegate: PC3.Button {
                        required property string modelData

                        text: fullRoot.presetLabel(modelData)
                        checkable: true
                        checked: fullRoot.equalizer.preset === modelData

                        onClicked:
                            fullRoot.backend.setEqualizerPreset(modelData)
                    }
                }
            }

            ToggleRow {
                id: dseeToggle

                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                visible: fullRoot.connected &&
                         fullRoot.capabilities.dsee

                label: "DSEE"
                caption: fullRoot.equalizer.dsee_type || ""
                checked: fullRoot.equalizer.dsee_enabled === true

                onTriggered:
                    fullRoot.backend.setDsee(!dseeToggle.checked)
            }

            SectionTitle {
                text: "VOLUME"
                visible: fullRoot.connected &&
                         fullRoot.capabilities.playback_volume
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                visible: fullRoot.connected &&
                         fullRoot.capabilities.playback_volume

                spacing: 2

                RowLayout {
                    Layout.fillWidth: true

                    QQC2.Label {
                        text: "Volume"
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    QQC2.Label {
                        opacity: 0.7
                        text: Math.round(volumeSlider.value) + "%"
                    }
                }

                PC3.Slider {
                    id: volumeSlider

                    Layout.fillWidth: true

                    from: 0
                    to: 100
                    stepSize: 1

                    value: fullRoot.playback.volume || 0

                    onMoved: fullRoot.backend.setVolume(value)
                }
            }

            SectionTitle {
                text: "CONNECTION"

                visible: fullRoot.connected &&
                         fullRoot.capabilities.connection_mode
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter

                visible: fullRoot.connected &&
                         fullRoot.capabilities.connection_mode

                spacing: Kirigami.Units.smallSpacing

                PC3.Button {
                    text: "Sound quality"
                    checkable: true
                    checked: fullRoot.connectionInfo.priority === "quality"

                    onClicked:
                        fullRoot.backend.setConnectionPriority("quality")
                }

                PC3.Button {
                    text: "Stable connection"
                    checkable: true
                    checked: fullRoot.connectionInfo.priority === "stable"

                    onClicked:
                        fullRoot.backend.setConnectionPriority("stable")
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing

                visible: !fullRoot.connected

                opacity: 0.7
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter

                text: (fullRoot.backend &&
                       fullRoot.backend.daemonReachable)
                    ? "Connect a compatible Sony headset, then keep this panel open while the control channel initializes."
                    : "Start sony-headphonesd to discover and control your headset."
            }
        }
    }

    component SectionTitle: QQC2.Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.leftMargin: Kirigami.Units.smallSpacing

        font.bold: true
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        opacity: 0.6
    }

    component BatteryRow: RowLayout {
        id: batteryRow

        property string label: ""
        property int level: -1
        property string charging: "unknown"

        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            text: batteryRow.label
            Layout.preferredWidth: Kirigami.Units.gridUnit * 4
        }

        PC3.ProgressBar {
            Layout.fillWidth: true

            from: 0
            to: 100
            value: batteryRow.level >= 0 ? batteryRow.level : 0
        }

        QQC2.Label {
            text: batteryRow.level >= 0
                ? batteryRow.level + "%"
                : "—"

            Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            horizontalAlignment: Text.AlignRight
        }

        QQC2.Label {
            text: "⚡"
            visible: batteryRow.charging === "yes"
        }
    }

    component ToggleRow: RowLayout {
        id: toggleRow

        property string label: ""
        property string caption: ""
        property bool checked: false

        signal triggered()

        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            QQC2.Label {
                Layout.fillWidth: true
                text: toggleRow.label
            }

            QQC2.Label {
                Layout.fillWidth: true

                visible: text.length > 0
                text: toggleRow.caption
                opacity: 0.6

                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                wrapMode: Text.WordWrap
            }
        }

        PC3.Switch {
            checked: toggleRow.checked
            onToggled: toggleRow.triggered()
        }
    }
}