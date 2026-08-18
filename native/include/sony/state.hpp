#pragma once

#include <array>
#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

namespace sony {

struct BatteryState {
  bool present{};
  int level{-1};
  std::string charging{"unknown"};
};

struct Capabilities {
  bool batterySingle{};
  bool batteryLeftRight{};
  bool batteryCase{};
  bool playbackMetadata{};
  bool playbackControl{};
  bool playbackVolume{};
  bool noiseCancelling{};
  bool ambientSound{};
  bool adaptiveAmbientSound{};
  bool speakToChat{};
  bool listeningMode{};
  bool equalizer{};
  bool dsee{};
  bool pairedDeviceManagement{};
  bool pairingMode{};
  bool generalSettings{};
  bool assignableControls{};
  bool noiseControlButton{};
  bool autoPowerOff{};
  bool wearingDetection{};
  bool autoPause{};
  bool headGesture{};
  bool voiceGuidance{};
  bool voiceGuidanceVolume{};
  bool shutdown{};
  bool connectionMode{};
  bool safeListening{};
};

struct DeviceState {
  std::string name;
  std::string model;
  std::string firmware;
  int protocol{};
  std::string codec{"unknown"};
};

struct NoiseState {
  std::string mode{"unknown"};
  int ambientLevel{1};
  bool focusOnVoice{};
  bool adaptive{};
  std::string adaptiveSensitivity{"unknown"};
};

struct SpeakToChatState {
  bool enabled{};
  std::string sensitivity{"unknown"};
  std::string timeout{"unknown"};
};

struct EqualizerState {
  std::string preset{"unknown"};
  std::vector<std::string> availablePresets;
  int clearBass{};
  std::vector<int> bands;
  bool dseeEnabled{};
  std::string dseeType{"unknown"};
};

struct PlaybackState {
  std::string status{"unknown"};
  int volume{};
};

struct ConnectionState {
  std::string priority{"unknown"};
};

struct State {
  std::uint64_t revision{};
  std::string phase{"idle"};
  bool connected{};
  DeviceState device;
  std::array<BatteryState, 4> battery;
  Capabilities capabilities;
  NoiseState noise;
  SpeakToChatState speakToChat;
  EqualizerState equalizer;
  PlaybackState playback;
  ConnectionState connection;
  std::string lastError;
};

std::string jsonEscape(const std::string& value);
std::string serializeState(const State& state);
std::filesystem::path stateDirectory();
std::filesystem::path stateFilePath();
std::filesystem::path runtimeDirectory();
std::filesystem::path socketPath();
bool ensurePrivateDirectory(const std::filesystem::path& path, std::string& error);
bool atomicWrite(const std::filesystem::path& path, const std::string& data, std::string& error);

}  // namespace sony
