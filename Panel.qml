pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.vyomjain6904.sony-headphones"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null

  readonly property color foreground: root.barForeground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: root.bar ? root.bar.urgent : foreground
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property var batteryRows: service ? Model.batteryRows(service.status) : []
  readonly property var eqPresets: ["off", "bright", "excited", "mellow", "relaxed", "vocal", "bass", "speech"]

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  onOpenedChanged: {
    if (!service) return
    service.setPanelOpen(root.opened)
    if (root.opened) {
      service.refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (!root.service || !root.service.connected) return
        var key = String(text).toLowerCase()
        if (key === "n" && root.service.status.capabilities.noiseCancelling) root.service.setNoiseMode(Model.NOISE_ANC)
        else if (key === "a" && root.service.status.capabilities.ambientSound) root.service.setNoiseMode(Model.NOISE_AMBIENT)
        else if (key === "o") root.service.setNoiseMode(Model.NOISE_OFF)
        else if (key === "r") root.service.requestRefresh()
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
          id: content
          width: parent.width
          spacing: Style.space(12)

          Text {
            width: parent.width
            text: root.service ? Model.deviceTitle(root.service.status) : "Sony Headphones"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: {
              if (!root.service) return "Service unavailable"
              var status = Model.phaseLabel(root.service.status.phase)
              if (root.service.status.connected) {
                var detail = Model.codecLabel(root.service.status.device.codec)
                if (root.service.status.device.firmware !== "") detail += " · firmware " + root.service.status.device.firmware
                status += " · " + detail
              }
              return status
            }
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Text {
            visible: root.service && (root.service.actionError !== "" || root.service.status.lastError !== "")
            width: parent.width
            text: root.service && root.service.actionError !== ""
              ? root.service.actionError
              : (root.service ? root.service.status.lastError : "")
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          SectionTitle { visible: root.batteryRows.length > 0; text: "BATTERY" }

          Repeater {
            model: root.batteryRows
            BatteryRow {
              required property var modelData
              width: content.width
              label: modelData.label
              battery: modelData.value
            }
          }

          SectionTitle {
            visible: root.service && root.service.connected
              && (root.service.status.capabilities.noiseCancelling || root.service.status.capabilities.ambientSound)
            text: "SOUND CONTROL"
          }

          Flow {
            visible: root.service && root.service.connected
              && (root.service.status.capabilities.noiseCancelling || root.service.status.capabilities.ambientSound)
            width: parent.width
            spacing: Style.space(6)

            ActionButton {
              visible: root.service && root.service.status.capabilities.noiseCancelling
              label: "Noise cancelling"
              selected: root.service && root.service.noiseMode === Model.NOISE_ANC
              onTriggered: root.service.setNoiseMode(Model.NOISE_ANC)
            }
            ActionButton {
              visible: root.service && root.service.status.capabilities.ambientSound
              label: "Ambient"
              selected: root.service && root.service.noiseMode === Model.NOISE_AMBIENT
              onTriggered: root.service.setNoiseMode(Model.NOISE_AMBIENT)
            }
            ActionButton {
              label: "Off"
              selected: root.service && root.service.noiseMode === Model.NOISE_OFF
              onTriggered: root.service.setNoiseMode(Model.NOISE_OFF)
            }
          }

          Column {
            visible: root.service && root.service.connected && root.service.status.capabilities.ambientSound
            width: parent.width
            spacing: Style.space(4)

            RowLayout {
              width: parent.width
              Text { text: "Ambient level"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
              Item { Layout.fillWidth: true }
              Text { text: root.service ? root.service.ambientLevel : ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
            }

            Slider {
              id: ambientSlider
              width: parent.width
              from: 1
              to: 20
              stepSize: 1
              live: true
              onPressedChanged: if (!pressed && root.service) root.service.setAmbientLevel(value)
              Binding {
                target: ambientSlider
                property: "value"
                value: root.service ? root.service.ambientLevel : 1
                when: !ambientSlider.pressed
              }
            }
          }

          ToggleRow {
            visible: root.service && root.service.connected && root.service.status.capabilities.ambientSound
            label: "Focus on voice"
            caption: "Prioritize voices in ambient mode"
            checked: root.service && root.service.focusOnVoice
            onTriggered: root.service.setFocusOnVoice(!root.service.focusOnVoice)
          }

          ToggleRow {
            visible: root.service && root.service.connected && root.service.status.capabilities.speakToChat
            label: "Speak-to-Chat"
            caption: "Pause or lower audio when you speak"
            checked: root.service && root.service.speakToChat
            onTriggered: root.service.setSpeakToChat(!root.service.speakToChat)
          }

          SectionTitle {
            visible: root.service && root.service.connected
              && (root.service.status.capabilities.equalizer || root.service.status.capabilities.dsee)
            text: "SOUND"
          }

          Flow {
            visible: root.service && root.service.connected && root.service.status.capabilities.equalizer
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: root.eqPresets
              ActionButton {
                required property string modelData
                label: Model.presetLabel(modelData)
                selected: root.service && root.service.equalizerPreset === modelData
                onTriggered: root.service.setEqualizerPreset(modelData)
              }
            }
          }

          ToggleRow {
            visible: root.service && root.service.connected && root.service.status.capabilities.dsee
            label: "DSEE"
            caption: root.service ? root.service.status.equalizer.dseeType : ""
            checked: root.service && root.service.dseeEnabled
            onTriggered: root.service.setDsee(!root.service.dseeEnabled)
          }

          SectionTitle {
            visible: root.service && root.service.connected
              && (root.service.status.capabilities.playbackControl || root.service.status.capabilities.playbackVolume)
            text: "PLAYBACK"
          }

          Row {
            visible: root.service && root.service.connected && root.service.status.capabilities.playbackControl
            spacing: Style.space(6)
            ActionButton { label: "Previous"; onTriggered: root.service.playback("previous") }
            ActionButton {
              label: root.service && root.service.status.playback.status === "playing" ? "Pause" : "Play"
              onTriggered: root.service.playback(root.service.status.playback.status === "playing" ? "pause" : "play")
            }
            ActionButton { label: "Next"; onTriggered: root.service.playback("next") }
          }

          Column {
            visible: root.service && root.service.connected && root.service.status.capabilities.playbackVolume
            width: parent.width
            spacing: Style.space(4)
            RowLayout {
              width: parent.width
              Text { text: "Volume"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
              Item { Layout.fillWidth: true }
              Text { text: root.service ? root.service.volume + "%" : ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
            }
            Slider {
              id: volumeSlider
              width: parent.width
              from: 0
              to: 100
              stepSize: 1
              live: true
              onPressedChanged: if (!pressed && root.service) root.service.setVolume(value)
              Binding {
                target: volumeSlider
                property: "value"
                value: root.service ? root.service.volume : 0
                when: !volumeSlider.pressed
              }
            }
          }

          SectionTitle {
            visible: root.service && root.service.connected && root.service.status.capabilities.connectionMode
            text: "CONNECTION"
          }

          Flow {
            visible: root.service && root.service.connected && root.service.status.capabilities.connectionMode
            width: parent.width
            spacing: Style.space(6)
            ActionButton {
              label: "Sound quality"
              selected: root.service && root.service.connectionPriority === "quality"
              onTriggered: root.service.setConnectionPriority("quality")
            }
            ActionButton {
              label: "Stable connection"
              selected: root.service && root.service.connectionPriority === "stable"
              onTriggered: root.service.setConnectionPriority("stable")
            }
          }

          Text {
            visible: root.service && !root.service.connected
            width: parent.width
            text: root.service.daemonReachable
              ? "Connect a compatible Sony headset, then keep this panel open while the control channel initializes."
              : "Start sony-headphonesd to discover and control your headset."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  component SectionTitle: Text {
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.bold: true
    font.letterSpacing: 0.8
  }

  component ActionButton: Rectangle {
    id: action
    property string label: ""
    property bool selected: false
    signal triggered()

    implicitWidth: actionText.implicitWidth + Style.space(18)
    implicitHeight: Style.space(32)
    radius: Style.space(6)
    color: selected ? Qt.lighter(root.foreground, 1.45) : Qt.darker(root.foreground, 3.4)
    opacity: actionTap.pressed ? 0.75 : 1.0

    Text {
      id: actionText
      anchors.centerIn: parent
      text: action.label
      color: selected ? Qt.darker(root.foreground, 3.8) : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: selected
    }
    TapHandler { id: actionTap; onTapped: action.triggered() }
  }

  component BatteryRow: RowLayout {
    id: batteryRow
    property string label: ""
    property var battery: Model.defaultBattery()

    spacing: Style.space(8)
    Text {
      text: batteryRow.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      Layout.preferredWidth: Style.space(78)
    }
    Rectangle {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      implicitHeight: Style.space(6)
      radius: height / 2
      color: Qt.darker(root.foreground, 3.2)
      Rectangle {
        width: parent.width * (batteryRow.battery.level === Model.UNKNOWN_LEVEL ? 0 : batteryRow.battery.level / 100)
        height: parent.height
        radius: parent.radius
        color: batteryRow.battery.level >= 0 && batteryRow.battery.level <= 20
          && batteryRow.battery.charging !== "yes" ? root.urgent : root.foreground
      }
    }
    Text {
      text: Model.levelText(batteryRow.battery.level)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignRight
      Layout.preferredWidth: Style.space(38)
    }
    Text {
      visible: Model.chargingLabel(batteryRow.battery.charging) !== ""
      text: Model.chargingLabel(batteryRow.battery.charging)
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  component ToggleRow: Rectangle {
    id: toggleRow
    property string label: ""
    property string caption: ""
    property bool checked: false
    signal triggered()

    width: parent ? parent.width : implicitWidth
    implicitHeight: toggleColumn.implicitHeight + Style.space(14)
    radius: Style.space(6)
    color: toggleTap.pressed ? Qt.darker(root.foreground, 2.9) : Qt.darker(root.foreground, 3.4)

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.space(7)
      Column {
        id: toggleColumn
        Layout.fillWidth: true
        spacing: Style.space(2)
        Text { text: toggleRow.label; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
        Text {
          visible: toggleRow.caption !== ""
          width: parent.width
          text: toggleRow.caption
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }
      Rectangle {
        implicitWidth: Style.space(34)
        implicitHeight: Style.space(18)
        radius: height / 2
        color: toggleRow.checked ? root.foreground : root.dim
        Rectangle {
          width: parent.height - Style.space(4)
          height: width
          radius: width / 2
          y: Style.space(2)
          x: toggleRow.checked ? parent.width - width - Style.space(2) : Style.space(2)
          color: toggleRow.checked ? Qt.darker(root.foreground, 3.8) : root.foreground
        }
      }
    }
    TapHandler { id: toggleTap; onTapped: toggleRow.triggered() }
  }
}
