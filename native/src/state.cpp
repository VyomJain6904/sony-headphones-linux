#include "sony/state.hpp"

#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <pwd.h>
#include <sstream>
#include <string_view>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

namespace sony {
namespace {

std::string boolJson(bool value) { return value ? "true" : "false"; }

std::filesystem::path homeDirectory() {
  if (const char* value = std::getenv("HOME"); value != nullptr && *value != '\0') return value;
  if (const passwd* entry = getpwuid(getuid()); entry != nullptr && entry->pw_dir != nullptr) return entry->pw_dir;
  return {};
}

void appendBattery(std::ostringstream& out, const BatteryState& battery) {
  out << "{\"present\":" << boolJson(battery.present)
      << ",\"level\":" << battery.level
      << ",\"charging\":\"" << jsonEscape(battery.charging) << "\"}";
}

void appendCapability(std::ostringstream& out, std::string_view name, bool value, bool& first) {
  if (!first) out << ',';
  first = false;
  out << '\"' << name << "\":" << boolJson(value);
}

}  // namespace

std::string jsonEscape(const std::string& value) {
  std::ostringstream out;
  for (const char byte : value) {
    const auto character = static_cast<unsigned char>(byte);
    switch (character) {
      case '\"': out << "\\\""; break;
      case '\\': out << "\\\\"; break;
      case '\b': out << "\\b"; break;
      case '\f': out << "\\f"; break;
      case '\n': out << "\\n"; break;
      case '\r': out << "\\r"; break;
      case '\t': out << "\\t"; break;
      default:
        if (character < 0x20U) {
          constexpr char digits[] = "0123456789abcdef";
          out << "\\u00" << digits[(character >> 4U) & 0x0fU] << digits[character & 0x0fU];
        } else {
          out << static_cast<char>(character);
        }
    }
  }
  return out.str();
}

std::string serializeState(const State& state) {
  std::ostringstream out;
  out << "{\"schema_version\":1"
      << ",\"daemon_version\":\"" << SONY_HEADPHONES_VERSION << '\"'
      << ",\"revision\":" << state.revision
      << ",\"phase\":\"" << jsonEscape(state.phase) << '\"'
      << ",\"connected\":" << boolJson(state.connected)
      << ",\"device\":{\"name\":\"" << jsonEscape(state.device.name)
      << "\",\"model\":\"" << jsonEscape(state.device.model)
      << "\",\"firmware\":\"" << jsonEscape(state.device.firmware)
      << "\",\"protocol\":" << state.device.protocol
      << ",\"codec\":\"" << jsonEscape(state.device.codec) << "\"}"
      << ",\"battery\":{\"main\":";
  appendBattery(out, state.battery[0]);
  out << ",\"left\":";
  appendBattery(out, state.battery[1]);
  out << ",\"right\":";
  appendBattery(out, state.battery[2]);
  out << ",\"case\":";
  appendBattery(out, state.battery[3]);
  out << "},\"capabilities\":{";

  bool first = true;
  const Capabilities& capability = state.capabilities;
  appendCapability(out, "battery_single", capability.batterySingle, first);
  appendCapability(out, "battery_left_right", capability.batteryLeftRight, first);
  appendCapability(out, "battery_case", capability.batteryCase, first);
  appendCapability(out, "playback_metadata", capability.playbackMetadata, first);
  appendCapability(out, "playback_control", capability.playbackControl, first);
  appendCapability(out, "playback_volume", capability.playbackVolume, first);
  appendCapability(out, "noise_cancelling", capability.noiseCancelling, first);
  appendCapability(out, "ambient_sound", capability.ambientSound, first);
  appendCapability(out, "adaptive_ambient_sound", capability.adaptiveAmbientSound, first);
  appendCapability(out, "speak_to_chat", capability.speakToChat, first);
  appendCapability(out, "listening_mode", capability.listeningMode, first);
  appendCapability(out, "equalizer", capability.equalizer, first);
  appendCapability(out, "dsee", capability.dsee, first);
  appendCapability(out, "paired_device_management", capability.pairedDeviceManagement, first);
  appendCapability(out, "pairing_mode", capability.pairingMode, first);
  appendCapability(out, "general_settings", capability.generalSettings, first);
  appendCapability(out, "assignable_controls", capability.assignableControls, first);
  appendCapability(out, "noise_control_button", capability.noiseControlButton, first);
  appendCapability(out, "auto_power_off", capability.autoPowerOff, first);
  appendCapability(out, "wearing_detection", capability.wearingDetection, first);
  appendCapability(out, "auto_pause", capability.autoPause, first);
  appendCapability(out, "head_gesture", capability.headGesture, first);
  appendCapability(out, "voice_guidance", capability.voiceGuidance, first);
  appendCapability(out, "voice_guidance_volume", capability.voiceGuidanceVolume, first);
  appendCapability(out, "shutdown", capability.shutdown, first);
  appendCapability(out, "connection_mode", capability.connectionMode, first);
  appendCapability(out, "safe_listening", capability.safeListening, first);

  out << "},\"noise\":{\"mode\":\"" << jsonEscape(state.noise.mode)
      << "\",\"ambient_level\":" << state.noise.ambientLevel
      << ",\"focus_on_voice\":" << boolJson(state.noise.focusOnVoice)
      << ",\"adaptive\":" << boolJson(state.noise.adaptive)
      << ",\"adaptive_sensitivity\":\"" << jsonEscape(state.noise.adaptiveSensitivity) << "\"}"
      << ",\"speak_to_chat\":{\"enabled\":" << boolJson(state.speakToChat.enabled)
      << ",\"sensitivity\":\"" << jsonEscape(state.speakToChat.sensitivity)
      << "\",\"timeout\":\"" << jsonEscape(state.speakToChat.timeout) << "\"}"
      << ",\"equalizer\":{\"preset\":\"" << jsonEscape(state.equalizer.preset)
      << "\",\"available_presets\":[";
  for (std::size_t index = 0; index < state.equalizer.availablePresets.size(); ++index) {
    if (index > 0) out << ',';
    out << '\"' << jsonEscape(state.equalizer.availablePresets[index]) << '\"';
  }
  out << "],\"clear_bass\":" << state.equalizer.clearBass << ",\"bands\":[";
  for (std::size_t index = 0; index < state.equalizer.bands.size(); ++index) {
    if (index > 0) out << ',';
    out << state.equalizer.bands[index];
  }
  out << "],\"dsee_enabled\":" << boolJson(state.equalizer.dseeEnabled)
      << ",\"dsee_type\":\"" << jsonEscape(state.equalizer.dseeType) << "\"}"
      << ",\"playback\":{\"status\":\"" << jsonEscape(state.playback.status)
      << "\",\"volume\":" << state.playback.volume << '}'
      << ",\"connection\":{\"priority\":\"" << jsonEscape(state.connection.priority) << "\"}"
      << ",\"last_error\":\"" << jsonEscape(state.lastError) << "\"}\n";
  return out.str();
}

std::filesystem::path stateDirectory() {
  if (const char* value = std::getenv("XDG_STATE_HOME"); value != nullptr && *value != '\0') {
    return std::filesystem::path(value) / "sony-headphones";
  }
  return homeDirectory() / ".local" / "state" / "sony-headphones";
}

std::filesystem::path stateFilePath() { return stateDirectory() / "status.json"; }

std::filesystem::path runtimeDirectory() {
  if (const char* value = std::getenv("XDG_RUNTIME_DIR"); value != nullptr && *value != '\0') {
    return std::filesystem::path(value) / "sony-headphones";
  }
  return std::filesystem::path("/tmp") / ("sony-headphones-" + std::to_string(getuid()));
}

std::filesystem::path socketPath() { return runtimeDirectory() / "daemon.sock"; }

bool ensurePrivateDirectory(const std::filesystem::path& path, std::string& error) {
  std::error_code filesystemError;
  std::filesystem::create_directories(path, filesystemError);
  if (filesystemError) {
    error = "could not create " + path.string() + ": " + filesystemError.message();
    return false;
  }
  if (::chmod(path.c_str(), S_IRWXU) != 0) {
    error = "could not secure " + path.string() + ": " + std::strerror(errno);
    return false;
  }
  return true;
}

bool atomicWrite(const std::filesystem::path& path, const std::string& data, std::string& error) {
  if (!ensurePrivateDirectory(path.parent_path(), error)) return false;
  const std::filesystem::path temporary = path.string() + ".tmp." + std::to_string(getpid());
  const int descriptor = ::open(temporary.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, S_IRUSR | S_IWUSR);
  if (descriptor < 0) {
    error = "could not open temporary state: " + std::string(std::strerror(errno));
    return false;
  }

  std::size_t offset = 0;
  bool success = true;
  while (offset < data.size()) {
    const ssize_t written = ::write(descriptor, data.data() + offset, data.size() - offset);
    if (written < 0) {
      if (errno == EINTR) continue;
      error = "could not write state: " + std::string(std::strerror(errno));
      success = false;
      break;
    }
    offset += static_cast<std::size_t>(written);
  }
  if (success && ::fsync(descriptor) != 0) {
    error = "could not flush state: " + std::string(std::strerror(errno));
    success = false;
  }
  if (::close(descriptor) != 0 && success) {
    error = "could not close state: " + std::string(std::strerror(errno));
    success = false;
  }
  if (!success) {
    std::error_code ignored;
    std::filesystem::remove(temporary, ignored);
    return false;
  }
  if (::rename(temporary.c_str(), path.c_str()) != 0) {
    error = "could not publish state: " + std::string(std::strerror(errno));
    std::error_code ignored;
    std::filesystem::remove(temporary, ignored);
    return false;
  }
  return true;
}

}  // namespace sony
