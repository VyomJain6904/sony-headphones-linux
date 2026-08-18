pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

  readonly property color foreground: root.bar ? root.bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: root.bar ? root.bar.urgent : Color.urgent
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property var batteryRows: service ? Model.batteryRows(service.status) : []
  readonly property var eqPresets: service ? service.status.equalizer.availablePresets : []
  property bool cursorActive: false
  property string focusSection: "noise"
  property int selectedIndex: 0

  readonly property var noiseActions: {
    var actions = []
    if (!service || !service.connected) return actions
    if (service.status.capabilities.noiseCancelling)
      actions.push({ key: Model.NOISE_ANC, label: "Noise cancelling", icon: "", selected: service.noiseMode === Model.NOISE_ANC })
    if (service.status.capabilities.ambientSound)
      actions.push({ key: Model.NOISE_AMBIENT, label: "Ambient", icon: "", selected: service.noiseMode === Model.NOISE_AMBIENT })
    actions.push({ key: Model.NOISE_OFF, label: "Off", icon: "", selected: service.noiseMode === Model.NOISE_OFF })
    return actions
  }
  readonly property var equalizerActions: {
    var actions = []
    for (var index = 0; index < eqPresets.length; ++index) {
      var preset = eqPresets[index]
      actions.push({ key: preset, label: Model.presetLabel(preset), icon: "", selected: service && service.equalizerPreset === preset })
    }
    return actions
  }
  readonly property var connectionActions: service && service.connected && service.status.capabilities.connectionMode ? [
    { key: "quality", label: "Sound quality", icon: "", selected: service.connectionPriority === "quality" },
    { key: "stable", label: "Stable connection", icon: "", selected: service.connectionPriority === "stable" }
  ] : []
  readonly property var visibleSections: {
    var sections = []
    if (noiseActions.length > 0) sections.push("noise")
    if (service && service.connected && service.status.capabilities.ambientSound) {
      sections.push("ambient")
      sections.push("focus")
    }
    if (service && service.connected && service.status.capabilities.speakToChat) sections.push("speak")
    if (equalizerActions.length > 0) sections.push("equalizer")
    if (service && service.connected && service.status.capabilities.dsee) sections.push("dsee")
    if (service && service.connected && service.status.capabilities.playbackVolume) sections.push("volume")
    if (connectionActions.length > 0) sections.push("connection")
    return sections
  }

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function sectionActions(section) {
    if (section === "noise") return noiseActions
    if (section === "equalizer") return equalizerActions
    if (section === "connection") return connectionActions
    return []
  }

  function sectionIsSlider(section) { return section === "ambient" || section === "volume" }

  function firstIndexForSection(section) { return sectionIsSlider(section) ? -1 : 0 }

  function clampCursor() {
    if (visibleSections.length === 0) {
      cursorActive = false
      return
    }
    if (visibleSections.indexOf(focusSection) < 0) {
      focusSection = visibleSections[0]
      selectedIndex = firstIndexForSection(focusSection)
      return
    }
    if (sectionIsSlider(focusSection)) {
      selectedIndex = -1
      return
    }
    var count = sectionActions(focusSection).length
    if (focusSection === "focus" || focusSection === "speak" || focusSection === "dsee") count = 1
    if (count < 1) {
      selectedIndex = 0
      return
    }
    selectedIndex = Math.max(0, Math.min(count - 1, selectedIndex))
  }

  function setCursor(section, index, item) {
    cursorActive = true
    focusSection = section
    selectedIndex = index
    if (item) ensureCursorVisible(item)
  }

  function moveCursorVertical(delta) {
    if (visibleSections.length === 0) return
    if (!cursorActive) {
      cursorActive = true
      clampCursor()
      return
    }
    var current = visibleSections.indexOf(focusSection)
    if (current < 0) current = 0
    var next = Math.max(0, Math.min(visibleSections.length - 1, current + delta))
    focusSection = visibleSections[next]
    selectedIndex = firstIndexForSection(focusSection)
  }

  function moveCursorHorizontal(delta) {
    if (!cursorActive) {
      moveCursorVertical(1)
      return
    }
    if (focusSection === "ambient" && service) {
      service.setAmbientLevel(service.ambientLevel + delta)
      return
    }
    if (focusSection === "volume" && service) {
      service.setVolume(service.volume + delta * 5)
      return
    }
    var count = sectionActions(focusSection).length
    if (count > 0) selectedIndex = Math.max(0, Math.min(count - 1, selectedIndex + delta))
  }

  function activateAction(section, key) {
    if (!service || !service.connected) return
    if (section === "noise") service.setNoiseMode(key)
    else if (section === "equalizer") service.setEqualizerPreset(key)
    else if (section === "connection") service.setConnectionPriority(key)
  }

  function activateCursor() {
    if (!cursorActive || !service || !service.connected) return
    var actions = sectionActions(focusSection)
    if (actions.length > 0 && selectedIndex >= 0 && selectedIndex < actions.length) {
      activateAction(focusSection, actions[selectedIndex].key)
      return
    }
    if (focusSection === "focus") service.setFocusOnVoice(!service.focusOnVoice)
    else if (focusSection === "speak") service.setSpeakToChat(!service.speakToChat)
    else if (focusSection === "dsee") service.setDsee(!service.dseeEnabled)
  }

  function resetScroll() {
    var flick = scrollArea ? scrollArea.contentItem : null
    if (flick && flick.contentY !== undefined) flick.contentY = 0
  }

  function ensureCursorVisible(item) {
    if (!item || !scrollArea) return
    var flick = scrollArea.contentItem
    if (!flick || flick.contentY === undefined) return
    var margin = Style.space(6)
    var point = item.mapToItem(flick.contentItem || flick, 0, 0)
    var top = point.y
    var bottom = top + (item.height || 0)
    var maxY = Math.max(0, (flick.contentHeight || 0) - flick.height)
    if (top < flick.contentY + margin) flick.contentY = Math.max(0, Math.min(maxY, top - margin))
    else if (bottom > flick.contentY + flick.height - margin)
      flick.contentY = Math.max(0, Math.min(maxY, bottom + margin - flick.height))
  }

  onVisibleSectionsChanged: Qt.callLater(clampCursor)

  onOpenedChanged: {
    if (!service) return
    service.setPanelOpen(root.opened)
    if (root.opened) {
      service.refresh()
      cursorActive = false
      Qt.callLater(function() {
        root.clampCursor()
        root.resetScroll()
        keyCatcher.forceActiveFocus()
      })
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (!root.service || !root.service.connected) return
        if (dy !== 0) root.moveCursorVertical(dy)
        else if (dx !== 0) root.moveCursorHorizontal(dx)
      }
      onActivateRequested: root.activateCursor()
      onTextKey: function(text) {
        if (!root.service || !root.service.connected) return
        var key = String(text).toLowerCase()
        if (key === "n" && root.service.status.capabilities.noiseCancelling) root.service.setNoiseMode(Model.NOISE_ANC)
        else if (key === "a" && root.service.status.capabilities.ambientSound) root.service.setNoiseMode(Model.NOISE_AMBIENT)
        else if (key === "o") root.service.setNoiseMode(Model.NOISE_OFF)
        else if (key === "r") root.service.requestRefresh()
      }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: content.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: content.implicitHeight > scrollArea.height
        }

        Column {
          id: content
          width: scrollArea.availableWidth
          spacing: Style.spacing.panelGap

          PanelHero {
            width: parent.width
            title: root.service ? Model.deviceTitle(root.service.status) : "Sony Headphones"
            meta: {
              if (!root.service) return "Service unavailable"
              var status = Model.phaseLabel(root.service.status.phase)
              if (root.service.status.connected) {
                var detail = Model.codecLabel(root.service.status.device.codec)
                if (root.service.status.device.firmware !== "") detail += " · firmware " + root.service.status.device.firmware
                status += " · " + detail
              }
              return status
            }
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: Model.HEADPHONES_ICON
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
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

          CenteredButtonGroup {
            visible: root.service && root.service.connected
              && (root.service.status.capabilities.noiseCancelling || root.service.status.capabilities.ambientSound)
            width: parent.width
            sectionName: "noise"
            actions: root.noiseActions
            maximumColumns: 3
          }

          Column {
            visible: root.service && root.service.connected && root.service.status.capabilities.ambientSound
            width: parent.width
            spacing: Style.spacing.labelGap

            RowLayout {
              width: parent.width
              Text { text: "Ambient level"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
              Item { Layout.fillWidth: true }
              Text {
                text: ambientSlider.dragging ? Math.round(ambientSlider.liveValue) : (root.service ? root.service.ambientLevel : "")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }

            CursorSurface {
              width: parent.width
              height: ambientSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.focusSection === "ambient"
              onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(this)
              foreground: root.foreground
              outline: true

              PanelSlider {
                id: ambientSlider
                property real releaseValue: 1
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: 1
                maximum: 20
                step: 1
                integer: true
                onMoved: function(value) { releaseValue = value }
                onReleased: function() {
                  if (root.service) root.service.setAmbientLevel(releaseValue)
                }
                Binding {
                  target: ambientSlider
                  property: "value"
                  value: root.service ? root.service.ambientLevel : 1
                  when: !ambientSlider.dragging
                }
              }
              HoverHandler {
                onHoveredChanged: if (hovered) root.setCursor("ambient", -1, parent)
              }
            }
          }

          ToggleRow {
            visible: root.service && root.service.connected && root.service.status.capabilities.ambientSound
            sectionName: "focus"
            label: "Focus on voice"
            caption: "Prioritize voices in ambient mode"
            checked: root.service && root.service.focusOnVoice
            onTriggered: root.service.setFocusOnVoice(!root.service.focusOnVoice)
          }

          ToggleRow {
            visible: root.service && root.service.connected && root.service.status.capabilities.speakToChat
            sectionName: "speak"
            label: "Speak-to-Chat"
            caption: "Pause or lower audio when you speak"
            checked: root.service && root.service.speakToChat
            onTriggered: root.service.setSpeakToChat(!root.service.speakToChat)
          }

          SectionTitle {
            visible: root.service && root.service.connected
              && (root.eqPresets.length > 0 || root.service.status.capabilities.dsee)
            text: "SOUND"
          }

          CenteredButtonGroup {
            visible: root.service && root.service.connected && root.eqPresets.length > 0
            width: parent.width
            sectionName: "equalizer"
            actions: root.equalizerActions
            maximumColumns: 2
          }

          ToggleRow {
            visible: root.service && root.service.connected && root.service.status.capabilities.dsee
            sectionName: "dsee"
            label: "DSEE"
            caption: root.service ? root.service.status.equalizer.dseeType : ""
            checked: root.service && root.service.dseeEnabled
            onTriggered: root.service.setDsee(!root.service.dseeEnabled)
          }

          SectionTitle {
            visible: root.service && root.service.connected && root.service.status.capabilities.playbackVolume
            text: "VOLUME"
          }

          Column {
            visible: root.service && root.service.connected && root.service.status.capabilities.playbackVolume
            width: parent.width
            spacing: Style.spacing.labelGap
            RowLayout {
              width: parent.width
              Text { text: "Volume"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
              Item { Layout.fillWidth: true }
              Text {
                text: (volumeSlider.dragging ? Math.round(volumeSlider.liveValue) : (root.service ? root.service.volume : "")) + "%"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
            CursorSurface {
              width: parent.width
              height: volumeSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.focusSection === "volume"
              onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(this)
              foreground: root.foreground
              outline: true

              PanelSlider {
                id: volumeSlider
                property real releaseValue: 0
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: 0
                maximum: 100
                step: 1
                integer: true
                onMoved: function(value) { releaseValue = value }
                onReleased: function() {
                  if (root.service) root.service.setVolume(releaseValue)
                }
                Binding {
                  target: volumeSlider
                  property: "value"
                  value: root.service ? root.service.volume : 0
                  when: !volumeSlider.dragging
                }
              }
              HoverHandler {
                onHoveredChanged: if (hovered) root.setCursor("volume", -1, parent)
              }
            }
          }

          SectionTitle {
            visible: root.service && root.service.connected && root.service.status.capabilities.connectionMode
            text: "CONNECTION"
          }

          CenteredButtonGroup {
            visible: root.service && root.service.connected && root.service.status.capabilities.connectionMode
            width: parent.width
            sectionName: "connection"
            actions: root.connectionActions
            maximumColumns: 2
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

  component SectionTitle: PanelSectionHeader {
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  component ActionButton: Button {
    id: action
    property string icon: ""
    property string label: ""
    signal triggered()

    text: label
    iconText: icon
    bordered: true
    foreground: root.foreground
    accent: Color.accent
    fontFamily: root.fontFamily
    fontSize: Style.font.bodySmall
    iconSize: Style.font.icon
    onClicked: action.triggered()
  }

  component CenteredButtonGroup: Item {
    id: buttonGroup
    property string sectionName: ""
    property var actions: []
    property int maximumColumns: 3
    readonly property int columnCount: width < Style.space(290)
      ? 1
      : Math.max(1, Math.min(maximumColumns, actions.length))
    readonly property int rowCount: actions.length > 0 ? Math.ceil(actions.length / columnCount) : 0

    implicitHeight: rows.implicitHeight

    Column {
      id: rows
      width: parent.width
      spacing: Style.spacing.md

      Repeater {
        model: buttonGroup.rowCount

        Item {
          id: rowSlot
          required property int index
          width: rows.width
          implicitHeight: buttonRow.implicitHeight

          RowLayout {
            id: buttonRow
            width: parent.width
            spacing: Style.spacing.md

            Item { Layout.fillWidth: true }

            Repeater {
              model: buttonGroup.actions.slice(
                rowSlot.index * buttonGroup.columnCount,
                Math.min(buttonGroup.actions.length, (rowSlot.index + 1) * buttonGroup.columnCount))

              ActionButton {
                id: groupedButton
                required property var modelData
                required property int index
                readonly property int actionIndex: rowSlot.index * buttonGroup.columnCount + index

                icon: modelData.icon || ""
                label: modelData.label || ""
                selected: modelData.selected === true
                hasCursor: root.cursorActive && root.focusSection === buttonGroup.sectionName
                  && root.selectedIndex === actionIndex
                onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(groupedButton)
                onHovered: function(isHovered) {
                  if (isHovered) root.setCursor(buttonGroup.sectionName, actionIndex, groupedButton)
                }
                onTriggered: root.activateAction(buttonGroup.sectionName, modelData.key)
              }
            }

            Item { Layout.fillWidth: true }
          }
        }
      }
    }
  }

  component BatteryRow: RowLayout {
    id: batteryRow
    property string label: ""
    property var battery: Model.defaultBattery()

    spacing: Style.spacing.controlGap
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
      color: Style.normalFillFor(root.foreground, Color.accent)
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

  component ToggleRow: Toggle {
    id: toggleRow
    property string sectionName: ""
    property string caption: ""
    signal triggered()

    width: parent ? parent.width : implicitWidth
    description: caption
    foreground: root.foreground
    accent: Color.accent
    fontFamily: root.fontFamily
    titleSize: Style.font.body
    descriptionSize: Style.font.bodySmall
    hasCursor: root.cursorActive && root.focusSection === sectionName
    onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(toggleRow)
    onHovered: function(isHovered) {
      if (isHovered) root.setCursor(sectionName, 0, toggleRow)
    }
    onClicked: toggleRow.triggered()
  }
}
