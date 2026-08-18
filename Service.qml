import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property var status: Model.defaultStatus()
  property bool daemonReachable: false
  property string actionError: ""

  property string _pendingField: ""
  property var _pendingValue: null
  property var _queued: null

  readonly property string ctlPath: String(setting("ctlPath", "") || "sony-headphonesctl")
  readonly property string statePath: (Quickshell.env("XDG_STATE_HOME")
    || Quickshell.env("HOME") + "/.local/state") + "/sony-headphones/status.json"
  readonly property bool busy: commandProcess.running
  readonly property bool connected: status.connected
  readonly property string noiseMode: _pendingField === "noiseMode" ? _pendingValue : status.noise.mode
  readonly property int ambientLevel: _pendingField === "ambientLevel" ? _pendingValue : status.noise.ambientLevel
  readonly property bool focusOnVoice: _pendingField === "focusOnVoice" ? _pendingValue : status.noise.focusOnVoice
  readonly property bool speakToChat: _pendingField === "speakToChat" ? _pendingValue : status.speakToChat.enabled
  readonly property bool dseeEnabled: _pendingField === "dseeEnabled" ? _pendingValue : status.equalizer.dseeEnabled
  readonly property string equalizerPreset: _pendingField === "equalizerPreset" ? _pendingValue : status.equalizer.preset
  readonly property string connectionPriority: _pendingField === "connectionPriority" ? _pendingValue : status.connection.priority
  readonly property int volume: _pendingField === "volume" ? _pendingValue : status.playback.volume

  readonly property int settleHoldMs: 4000
  readonly property int actionErrorMs: 3500

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function refresh() {
    stateFile.reload()
  }

  function _reported(field) {
    if (field === "noiseMode") return status.noise.mode
    if (field === "ambientLevel") return status.noise.ambientLevel
    if (field === "focusOnVoice") return status.noise.focusOnVoice
    if (field === "speakToChat") return status.speakToChat.enabled
    if (field === "dseeEnabled") return status.equalizer.dseeEnabled
    if (field === "equalizerPreset") return status.equalizer.preset
    if (field === "connectionPriority") return status.connection.priority
    if (field === "volume") return status.playback.volume
    return undefined
  }

  function applyLine(raw) {
    var parsed = Model.parseStatus(raw)
    if (!parsed.ok) {
      daemonReachable = true
      status = parsed
      return
    }
    daemonReachable = true
    status = parsed
    if (_pendingField !== "" && _reported(_pendingField) === _pendingValue) clearPending()
  }

  function stateGone() {
    daemonReachable = false
    status = Model.defaultStatus()
  }

  function clearPending() {
    _pendingField = ""
    _pendingValue = null
    settleTimer.stop()
  }

  function _send(args, field, optimistic) {
    if (!args || args.length === 0) return
    var request = { args: args, field: field || "", optimistic: optimistic }
    if (commandProcess.running) {
      _queued = request
      if (request.field !== "") {
        _pendingValue = request.optimistic
        _pendingField = request.field
        settleTimer.restart()
      }
      return
    }

    if (request.field !== "") {
      _pendingValue = request.optimistic
      _pendingField = request.field
      settleTimer.restart()
    }
    actionError = ""
    commandProcess.command = [ctlPath].concat(request.args)
    commandProcess.running = true
  }

  function setPanelOpen(opened) { _send([opened ? "panel-open" : "panel-close"], "", null) }
  function requestRefresh() { _send(["refresh"], "", null) }
  function setNoiseMode(mode) { _send(Model.noiseArgs(mode), "noiseMode", mode) }
  function setAmbientLevel(level) {
    var value = Model.clamp(Math.round(level), 1, 20)
    _send(Model.ambientArgs(value), "ambientLevel", value)
  }
  function setFocusOnVoice(enabled) { _send(Model.toggleArgs("focus-on-voice", enabled), "focusOnVoice", enabled) }
  function setSpeakToChat(enabled) { _send(Model.toggleArgs("speak-to-chat", enabled), "speakToChat", enabled) }
  function setDsee(enabled) { _send(Model.toggleArgs("dsee", enabled), "dseeEnabled", enabled) }
  function setEqualizerPreset(preset) { _send(["eq-preset", preset], "equalizerPreset", preset) }
  function setConnectionPriority(priority) { _send(["connection", priority], "connectionPriority", priority) }
  function setVolume(value) {
    var canonical = Model.canonicalVolumePercent(value)
    _send(Model.volumeArgs(canonical), "volume", canonical)
  }
  Timer {
    id: settleTimer
    interval: root.settleHoldMs
    repeat: false
    onTriggered: { root.clearPending(); root.refresh() }
  }

  Timer {
    id: errorTimer
    interval: root.actionErrorMs
    repeat: false
    onTriggered: root.actionError = ""
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyLine(text())
    onLoadFailed: root.stateGone()
  }

  Process {
    id: commandProcess
    running: false
    command: []
    stderr: StdioCollector { id: commandError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.clearPending()
        root.actionError = Model.elideError(commandError.text || "sony-headphonesctl rejected the command")
        errorTimer.restart()
      }
      root.refresh()
      if (root._queued) {
        var next = root._queued
        root._queued = null
        root._send(next.args, next.field, next.optimistic)
      }
    }
  }
}
