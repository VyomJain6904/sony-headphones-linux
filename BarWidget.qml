import QtQuick
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.vyomjain6904.sony-headphones"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property bool hideWhenDisconnected: setting("hideWhenDisconnected", false) === true

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
    panelLoader.item.service = sony
  }

  visible: !hideWhenDisconnected || sony.connected || sony.status.phase !== Model.PHASE_IDLE
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()

  Service {
    id: sony
    settings: root.settings
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.HEADPHONES_ICON
    tooltipText: sony.connected
      ? Model.deviceTitle(sony.status) + " · " + Model.levelText(Model.bestBattery(sony.status))
        + " · " + Model.noiseLabel(sony.noiseMode)
      : "Open Sony Headphones"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.RightButton && sony.connected) {
        if (sony.status.capabilities.noiseCancelling && sony.noiseMode !== Model.NOISE_ANC) sony.setNoiseMode(Model.NOISE_ANC)
        else if (sony.status.capabilities.ambientSound) sony.setNoiseMode(Model.NOISE_AMBIENT)
        else sony.setNoiseMode(Model.NOISE_OFF)
      }
    }
  }
}
