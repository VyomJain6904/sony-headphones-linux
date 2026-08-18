const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
const context = {}
vm.createContext(context)
vm.runInContext(source, context, { filename: "Model.js" })

const live = JSON.stringify({
  schema_version: 1,
  daemon_version: "0.2.0",
  revision: 7,
  phase: "ready",
  connected: true,
  device: { name: "WH-1000XM5", model: "WH-1000XM5", firmware: "2.3.1", protocol: 2, codec: "ldac" },
  battery: {
    main: { present: true, level: 73, charging: "no" },
    left: { present: false, level: 0, charging: "unknown" },
    right: { present: false, level: 0, charging: "unknown" },
    case: { present: false, level: 0, charging: "unknown" }
  },
  capabilities: {
    battery_single: true,
    noise_cancelling: true,
    ambient_sound: true,
    speak_to_chat: true,
    equalizer: true,
    dsee: true,
    connection_mode: true
  },
  noise: { mode: "anc", ambient_level: 12, focus_on_voice: false, adaptive: false, adaptive_sensitivity: "standard" },
  speak_to_chat: { enabled: true, sensitivity: "auto", timeout: "medium" },
  equalizer: {
    preset: "bright",
    available_presets: ["off", "bright", "bass"],
    clear_bass: 2,
    bands: [-2, -1, 0, 1, 2],
    dsee_enabled: true,
    dsee_type: "ultimate"
  },
  playback: { status: "playing", volume: 42 },
  connection: { priority: "quality" },
  last_error: ""
})

const status = context.parseStatus(live)
assert.equal(status.ok, true)
assert.equal(status.connected, true)
assert.equal(status.device.model, "WH-1000XM5")
assert.equal(status.device.codec, "ldac")
assert.equal(status.battery.main.level, 73)
assert.equal(status.capabilities.noiseCancelling, true)
assert.equal(status.capabilities.batteryCase, false)
assert.equal(status.noise.mode, "anc")
assert.equal(status.equalizer.bands.join(","), "-2,-1,0,1,2")
assert.equal(status.equalizer.availablePresets.join(","), "off,bright,bass")
assert.equal(context.codecLabel("ldac"), "LDAC")
assert.equal(context.deviceTitle(status), "WH-1000XM5")

const buds = context.parseStatus(JSON.stringify({
  schema_version: 1,
  connected: true,
  battery: {
    left: { present: true, level: 61, charging: "no" },
    right: { present: true, level: 59, charging: "yes" },
    case: { present: true, level: 88, charging: "no" }
  }
}))
assert.equal(context.bestBattery(buds), 60)
assert.equal(context.batteryRows(buds).length, 3)
assert.equal(context.chargingLabel(buds.battery.right.charging), "Charging")
assert.deepEqual(Array.from(buds.equalizer.availablePresets), [])

assert.equal(context.parseStatus("").ok, false)
assert.equal(context.parseStatus("not json").ok, false)
assert.equal(context.parseStatus("{}").ok, false)
const future = context.parseStatus('{"schema_version":2}')
assert.equal(future.schemaTooNew, true)
assert.match(future.lastError, /newer/)

assert.deepEqual(Array.from(context.noiseArgs("ambient")), ["noise", "ambient"])
assert.deepEqual(Array.from(context.noiseArgs("invalid")), [])
assert.deepEqual(Array.from(context.ambientArgs(99)), ["ambient-level", "20"])
assert.deepEqual(Array.from(context.volumeArgs(-5)), ["volume", "0"])
assert.equal(context.levelText(context.UNKNOWN_LEVEL), "--")
assert.equal(context.elideError("x\n   y"), "x y")
assert.ok(context.elideError("x".repeat(400)).length <= context.MAX_ERROR_CHARS)

console.log("model.test.js: all checks passed")
