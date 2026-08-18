// No QML imports: this file is intentionally executable in the Node test harness.

var SUPPORTED_SCHEMA = 1
var UNKNOWN_LEVEL = -1

var PHASE_IDLE = "idle"
var PHASE_DISCOVERING = "discovering"
var PHASE_CONNECTING = "connecting"
var PHASE_SYNCING = "syncing"
var PHASE_READY = "ready"
var PHASE_ERROR = "error"

var NOISE_UNKNOWN = "unknown"
var NOISE_OFF = "off"
var NOISE_ANC = "anc"
var NOISE_AMBIENT = "ambient"

var MAX_ERROR_CHARS = 160
var HEADPHONES_ICON = "󰋋"
var MDR_VOLUME_MAXIMUM = 30
var VOLUME_PERCENT_MAXIMUM = 100

function defaultBattery() {
  return { present: false, level: UNKNOWN_LEVEL, charging: "unknown" }
}

function defaultCapabilities() {
  return {
    batterySingle: false,
    batteryLeftRight: false,
    batteryCase: false,
    playbackMetadata: false,
    playbackControl: false,
    playbackVolume: false,
    noiseCancelling: false,
    ambientSound: false,
    adaptiveAmbientSound: false,
    speakToChat: false,
    listeningMode: false,
    equalizer: false,
    dsee: false,
    pairedDeviceManagement: false,
    pairingMode: false,
    generalSettings: false,
    assignableControls: false,
    noiseControlButton: false,
    autoPowerOff: false,
    wearingDetection: false,
    autoPause: false,
    headGesture: false,
    voiceGuidance: false,
    voiceGuidanceVolume: false,
    shutdown: false,
    connectionMode: false,
    safeListening: false
  }
}

function defaultStatus() {
  return {
    ok: false,
    schemaTooNew: false,
    schemaVersion: 0,
    daemonVersion: "",
    revision: 0,
    phase: PHASE_IDLE,
    connected: false,
    device: { name: "", model: "", firmware: "", protocol: 0, codec: "unknown" },
    battery: {
      main: defaultBattery(),
      left: defaultBattery(),
      right: defaultBattery(),
      case: defaultBattery()
    },
    capabilities: defaultCapabilities(),
    noise: {
      mode: NOISE_UNKNOWN,
      ambientLevel: 1,
      focusOnVoice: false,
      adaptive: false,
      adaptiveSensitivity: "unknown"
    },
    speakToChat: { enabled: false, sensitivity: "unknown", timeout: "unknown" },
    equalizer: {
      preset: "unknown", availablePresets: [], clearBass: 0, bands: [], dseeEnabled: false, dseeType: "unknown"
    },
    playback: { status: "unknown", volume: 0 },
    connection: { priority: "unknown" },
    lastError: ""
  }
}

function intOr(value, fallback) {
  var number = Number(value)
  return isFinite(number) ? Math.round(number) : fallback
}

function bool(value) {
  return value === true
}

function stringOr(value, fallback) {
  return typeof value === "string" ? value : fallback
}

function batteryFrom(raw) {
  var result = defaultBattery()
  if (!raw || typeof raw !== "object" || raw.present !== true) return result
  result.present = true
  result.level = clamp(intOr(raw.level, UNKNOWN_LEVEL), 0, 100)
  result.charging = stringOr(raw.charging, "unknown")
  return result
}

function capabilityFrom(raw) {
  var result = defaultCapabilities()
  if (!raw || typeof raw !== "object") return result
  var map = {
    battery_single: "batterySingle",
    battery_left_right: "batteryLeftRight",
    battery_case: "batteryCase",
    playback_metadata: "playbackMetadata",
    playback_control: "playbackControl",
    playback_volume: "playbackVolume",
    noise_cancelling: "noiseCancelling",
    ambient_sound: "ambientSound",
    adaptive_ambient_sound: "adaptiveAmbientSound",
    speak_to_chat: "speakToChat",
    listening_mode: "listeningMode",
    equalizer: "equalizer",
    dsee: "dsee",
    paired_device_management: "pairedDeviceManagement",
    pairing_mode: "pairingMode",
    general_settings: "generalSettings",
    assignable_controls: "assignableControls",
    noise_control_button: "noiseControlButton",
    auto_power_off: "autoPowerOff",
    wearing_detection: "wearingDetection",
    auto_pause: "autoPause",
    head_gesture: "headGesture",
    voice_guidance: "voiceGuidance",
    voice_guidance_volume: "voiceGuidanceVolume",
    shutdown: "shutdown",
    connection_mode: "connectionMode",
    safe_listening: "safeListening"
  }
  for (var key in map) result[map[key]] = bool(raw[key])
  return result
}

function parseStatus(raw) {
  var result = defaultStatus()
  var text = String(raw || "").trim()
  if (text === "") {
    result.lastError = "The Sony headphones status file is empty"
    return result
  }

  var value
  try {
    value = JSON.parse(text)
  } catch (error) {
    result.lastError = "Could not parse the Sony headphones status file"
    return result
  }
  if (!value || typeof value !== "object" || value.schema_version === undefined) {
    result.lastError = "The status file has no schema_version"
    return result
  }

  result.schemaVersion = intOr(value.schema_version, 0)
  if (result.schemaVersion > SUPPORTED_SCHEMA) {
    result.schemaTooNew = true
    result.lastError = "Daemon schema " + result.schemaVersion + " is newer than panel schema " + SUPPORTED_SCHEMA
    return result
  }

  result.ok = true
  result.daemonVersion = stringOr(value.daemon_version, "")
  result.revision = intOr(value.revision, 0)
  result.phase = stringOr(value.phase, PHASE_IDLE)
  result.connected = bool(value.connected)
  result.lastError = stringOr(value.last_error, "")

  var device = value.device || {}
  result.device = {
    name: stringOr(device.name, ""),
    model: stringOr(device.model, ""),
    firmware: stringOr(device.firmware, ""),
    protocol: intOr(device.protocol, 0),
    codec: stringOr(device.codec, "unknown")
  }

  var battery = value.battery || {}
  result.battery = {
    main: batteryFrom(battery.main),
    left: batteryFrom(battery.left),
    right: batteryFrom(battery.right),
    case: batteryFrom(battery["case"])
  }
  result.capabilities = capabilityFrom(value.capabilities)

  var noise = value.noise || {}
  result.noise = {
    mode: stringOr(noise.mode, NOISE_UNKNOWN),
    ambientLevel: clamp(intOr(noise.ambient_level, 1), 1, 20),
    focusOnVoice: bool(noise.focus_on_voice),
    adaptive: bool(noise.adaptive),
    adaptiveSensitivity: stringOr(noise.adaptive_sensitivity, "unknown")
  }

  var speak = value.speak_to_chat || {}
  result.speakToChat = {
    enabled: bool(speak.enabled),
    sensitivity: stringOr(speak.sensitivity, "unknown"),
    timeout: stringOr(speak.timeout, "unknown")
  }

  var equalizer = value.equalizer || {}
  result.equalizer = {
    preset: stringOr(equalizer.preset, "unknown"),
    availablePresets: Array.isArray(equalizer.available_presets)
      ? equalizer.available_presets.filter(function (preset) { return typeof preset === "string" })
      : [],
    clearBass: clamp(intOr(equalizer.clear_bass, 0), -10, 10),
    bands: Array.isArray(equalizer.bands) ? equalizer.bands.map(function (band) {
      return clamp(intOr(band, 0), -10, 10)
    }) : [],
    dseeEnabled: bool(equalizer.dsee_enabled),
    dseeType: stringOr(equalizer.dsee_type, "unknown")
  }

  var playback = value.playback || {}
  result.playback = {
    status: stringOr(playback.status, "unknown"),
    volume: clamp(intOr(playback.volume, 0), 0, 100)
  }
  var connection = value.connection || {}
  result.connection = { priority: stringOr(connection.priority, "unknown") }
  return result
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function deviceTitle(status) {
  if (status.device.model !== "") return status.device.model
  if (status.device.name !== "") return status.device.name
  return "Sony Headphones"
}

function phaseLabel(phase) {
  if (phase === PHASE_DISCOVERING) return "Discovering"
  if (phase === PHASE_CONNECTING) return "Connecting"
  if (phase === PHASE_SYNCING) return "Synchronizing"
  if (phase === PHASE_READY) return "Connected"
  if (phase === PHASE_ERROR) return "Connection error"
  return "Idle"
}

function levelText(level) {
  return level === UNKNOWN_LEVEL ? "--" : String(level) + "%"
}

function chargingLabel(value) {
  if (value === "yes") return "Charging"
  if (value === "complete") return "Charged"
  return ""
}

function batteryRows(status) {
  var rows = []
  var battery = status.battery
  if (battery.main.present) rows.push({ key: "main", label: "Headphones", value: battery.main })
  if (battery.left.present) rows.push({ key: "left", label: "Left", value: battery.left })
  if (battery.right.present) rows.push({ key: "right", label: "Right", value: battery.right })
  if (battery["case"].present) rows.push({ key: "case", label: "Case", value: battery["case"] })
  return rows
}

function bestBattery(status) {
  var battery = status.battery
  if (battery.main.present) return battery.main.level
  if (battery.left.present && battery.right.present) return Math.round((battery.left.level + battery.right.level) / 2)
  if (battery.left.present) return battery.left.level
  if (battery.right.present) return battery.right.level
  return UNKNOWN_LEVEL
}

function noiseLabel(mode) {
  if (mode === NOISE_OFF) return "Off"
  if (mode === NOISE_ANC) return "Noise cancelling"
  if (mode === NOISE_AMBIENT) return "Ambient sound"
  return "Unknown"
}

function codecLabel(codec) {
  var labels = { sbc: "SBC", aac: "AAC", ldac: "LDAC", aptx: "aptX", aptx_hd: "aptX HD", lc3: "LC3" }
  return labels[codec] || "Unknown codec"
}

function presetLabel(preset) {
  var labels = {
    off: "Off", rock: "Rock", pop: "Pop", jazz: "Jazz", dance: "Dance", edm: "EDM",
    r_and_b_hip_hop: "R&B / Hip-Hop", acoustic: "Acoustic", bright: "Bright", excited: "Excited",
    mellow: "Mellow", relaxed: "Relaxed", vocal: "Vocal", treble: "Treble Boost", bass: "Bass Boost",
    speech: "Speech", heavy: "Heavy", clear: "Clear", hard: "Hard", soft: "Soft", gaming: "Gaming",
    fps_1: "FPS 1", fps_2: "FPS 2", fps_3: "FPS 3", custom: "Custom",
    user_1: "User 1", user_2: "User 2", user_3: "User 3", user_4: "User 4", user_5: "User 5"
  }
  return labels[preset] || "Unknown"
}

function elideError(text) {
  var value = String(text || "").replace(/\s+/g, " ").trim()
  if (value.length <= MAX_ERROR_CHARS) return value
  return value.substring(0, MAX_ERROR_CHARS - 1) + "…"
}

function noiseArgs(mode) {
  if (mode !== NOISE_OFF && mode !== NOISE_ANC && mode !== NOISE_AMBIENT) return []
  return ["noise", mode]
}

function toggleArgs(command, enabled) {
  return [command, enabled ? "on" : "off"]
}

function ambientArgs(level) {
  return ["ambient-level", String(clamp(intOr(level, 1), 1, 20))]
}

function mdrVolumeToPercent(level) {
  var clamped = clamp(intOr(level, 0), 0, MDR_VOLUME_MAXIMUM)
  return Math.round(clamped * VOLUME_PERCENT_MAXIMUM / MDR_VOLUME_MAXIMUM)
}

function percentToMdrVolume(percent) {
  var clamped = clamp(intOr(percent, 0), 0, VOLUME_PERCENT_MAXIMUM)
  return Math.round(clamped * MDR_VOLUME_MAXIMUM / VOLUME_PERCENT_MAXIMUM)
}

function canonicalVolumePercent(percent) {
  return mdrVolumeToPercent(percentToMdrVolume(percent))
}

function volumeArgs(volume) {
  return ["volume", String(clamp(intOr(volume, 0), 0, VOLUME_PERCENT_MAXIMUM))]
}
