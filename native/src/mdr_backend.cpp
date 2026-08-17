#include "sony/backend.hpp"

#include <dbus/dbus.h>
#include <mdr-bt/ConnectionLinux.h>
#include <mdr-c/Base.h>
#include <mdr-c/Connection.h>
#include <mdr-c/Headphones.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cctype>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace sony {
namespace {

using Clock = std::chrono::steady_clock;
using namespace std::chrono_literals;

constexpr std::string_view kV2Uuid = "956c7b26-d49a-4ba8-b03f-b17d393cb6e2";
constexpr std::string_view kV1Uuid = "96cc203e-5068-46ad-b32d-e316f5e069ba";

struct MessageDeleter {
  void operator()(DBusMessage* message) const { if (message != nullptr) dbus_message_unref(message); }
};
using MessagePointer = std::unique_ptr<DBusMessage, MessageDeleter>;

struct ConnectionDeleter {
  void operator()(DBusConnection* connection) const { if (connection != nullptr) dbus_connection_unref(connection); }
};
using DBusConnectionPointer = std::unique_ptr<DBusConnection, ConnectionDeleter>;

struct LinuxConnectionDeleter {
  void operator()(MDRConnectionLinux* connection) const { if (connection != nullptr) mdrConnectionLinuxDestroy(connection); }
};
using LinuxConnectionPointer = std::unique_ptr<MDRConnectionLinux, LinuxConnectionDeleter>;

struct HeadphonesDeleter {
  void operator()(MDRHeadphones* headphones) const { if (headphones != nullptr) mdrHeadphonesDestroy(headphones); }
};
using HeadphonesPointer = std::unique_ptr<MDRHeadphones, HeadphonesDeleter>;

struct Candidate {
  std::string address;
  std::string name;
  std::vector<const char*> services;
};

std::string lower(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(), [](unsigned char character) {
    return static_cast<char>(std::tolower(character));
  });
  return value;
}

bool looksLikeSonyHeadphones(const std::string& value) {
  const std::string name = lower(value);
  constexpr std::array prefixes{"wh-", "wf-", "wi-", "mdr-", "linkbuds", "ult wear", "inzone"};
  return std::any_of(prefixes.begin(), prefixes.end(), [&](std::string_view prefix) {
    return name.starts_with(prefix);
  });
}

bool validAddress(const std::string& address) {
  if (address.size() != 17U) return false;
  for (std::size_t index = 0; index < address.size(); ++index) {
    if (index % 3U == 2U) {
      if (address[index] != ':') return false;
    } else if (!std::isxdigit(static_cast<unsigned char>(address[index]))) {
      return false;
    }
  }
  return true;
}

void parseStringVariant(DBusMessageIter& variant, std::string& destination) {
  DBusMessageIter value;
  dbus_message_iter_recurse(&variant, &value);
  const int type = dbus_message_iter_get_arg_type(&value);
  if (type != DBUS_TYPE_STRING && type != DBUS_TYPE_OBJECT_PATH) return;
  const char* text = nullptr;
  dbus_message_iter_get_basic(&value, &text);
  if (text != nullptr) destination = text;
}

void parseBoolVariant(DBusMessageIter& variant, bool& destination) {
  DBusMessageIter value;
  dbus_message_iter_recurse(&variant, &value);
  if (dbus_message_iter_get_arg_type(&value) != DBUS_TYPE_BOOLEAN) return;
  dbus_bool_t boolean = false;
  dbus_message_iter_get_basic(&value, &boolean);
  destination = boolean != false;
}

void parseUuidVariant(DBusMessageIter& variant, bool& hasV2, bool& hasV1) {
  DBusMessageIter array;
  dbus_message_iter_recurse(&variant, &array);
  if (dbus_message_iter_get_arg_type(&array) != DBUS_TYPE_ARRAY) return;
  DBusMessageIter entry;
  dbus_message_iter_recurse(&array, &entry);
  while (dbus_message_iter_get_arg_type(&entry) == DBUS_TYPE_STRING) {
    const char* text = nullptr;
    dbus_message_iter_get_basic(&entry, &text);
    const std::string uuid = lower(text != nullptr ? text : "");
    hasV2 = hasV2 || uuid == kV2Uuid;
    hasV1 = hasV1 || uuid == kV1Uuid;
    dbus_message_iter_next(&entry);
  }
}

std::vector<Candidate> discoverCandidates(std::string& error) {
  if (const char* configured = std::getenv("SONY_HEADPHONES_DEVICE"); configured != nullptr && *configured != '\0') {
    if (!validAddress(configured)) {
      error = "SONY_HEADPHONES_DEVICE is not a colon-separated Bluetooth address";
      return {};
    }
    return {{configured, "Configured Sony headphones", {MDR_SERVICE_UUID_XM5, MDR_SERVICE_UUID_LEGACY}}};
  }

  DBusError dbusError;
  dbus_error_init(&dbusError);
  DBusConnectionPointer bus(dbus_bus_get(DBUS_BUS_SYSTEM, &dbusError));
  if (!bus) {
    error = dbus_error_is_set(&dbusError) ? dbusError.message : "could not open the system D-Bus";
    dbus_error_free(&dbusError);
    return {};
  }
  dbus_error_free(&dbusError);

  MessagePointer request(dbus_message_new_method_call(
    "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"));
  if (!request) {
    error = "could not allocate a BlueZ discovery request";
    return {};
  }
  dbus_error_init(&dbusError);
  MessagePointer reply(dbus_connection_send_with_reply_and_block(bus.get(), request.get(), 3000, &dbusError));
  if (!reply) {
    error = dbus_error_is_set(&dbusError) ? dbusError.message : "BlueZ discovery returned no reply";
    dbus_error_free(&dbusError);
    return {};
  }
  dbus_error_free(&dbusError);

  DBusMessageIter root;
  if (!dbus_message_iter_init(reply.get(), &root) || dbus_message_iter_get_arg_type(&root) != DBUS_TYPE_ARRAY) {
    error = "BlueZ returned malformed managed objects";
    return {};
  }
  DBusMessageIter objects;
  dbus_message_iter_recurse(&root, &objects);
  std::vector<Candidate> candidates;
  while (dbus_message_iter_get_arg_type(&objects) == DBUS_TYPE_DICT_ENTRY) {
    DBusMessageIter object;
    dbus_message_iter_recurse(&objects, &object);
    dbus_message_iter_next(&object);  // object path -> interface array
    if (dbus_message_iter_get_arg_type(&object) != DBUS_TYPE_ARRAY) {
      dbus_message_iter_next(&objects);
      continue;
    }
    DBusMessageIter interfaces;
    dbus_message_iter_recurse(&object, &interfaces);
    while (dbus_message_iter_get_arg_type(&interfaces) == DBUS_TYPE_DICT_ENTRY) {
      DBusMessageIter interfaceEntry;
      dbus_message_iter_recurse(&interfaces, &interfaceEntry);
      const char* interfaceName = nullptr;
      if (dbus_message_iter_get_arg_type(&interfaceEntry) == DBUS_TYPE_STRING)
        dbus_message_iter_get_basic(&interfaceEntry, &interfaceName);
      dbus_message_iter_next(&interfaceEntry);
      if (interfaceName == nullptr || std::strcmp(interfaceName, "org.bluez.Device1") != 0
          || dbus_message_iter_get_arg_type(&interfaceEntry) != DBUS_TYPE_ARRAY) {
        dbus_message_iter_next(&interfaces);
        continue;
      }

      std::string address;
      std::string name;
      std::string alias;
      bool connected = false;
      bool hasV2 = false;
      bool hasV1 = false;
      DBusMessageIter properties;
      dbus_message_iter_recurse(&interfaceEntry, &properties);
      while (dbus_message_iter_get_arg_type(&properties) == DBUS_TYPE_DICT_ENTRY) {
        DBusMessageIter property;
        dbus_message_iter_recurse(&properties, &property);
        const char* propertyName = nullptr;
        if (dbus_message_iter_get_arg_type(&property) == DBUS_TYPE_STRING)
          dbus_message_iter_get_basic(&property, &propertyName);
        dbus_message_iter_next(&property);
        if (propertyName != nullptr && dbus_message_iter_get_arg_type(&property) == DBUS_TYPE_VARIANT) {
          if (std::strcmp(propertyName, "Address") == 0) parseStringVariant(property, address);
          else if (std::strcmp(propertyName, "Name") == 0) parseStringVariant(property, name);
          else if (std::strcmp(propertyName, "Alias") == 0) parseStringVariant(property, alias);
          else if (std::strcmp(propertyName, "Connected") == 0) parseBoolVariant(property, connected);
          else if (std::strcmp(propertyName, "UUIDs") == 0) parseUuidVariant(property, hasV2, hasV1);
        }
        dbus_message_iter_next(&properties);
      }

      const std::string displayName = !alias.empty() ? alias : name;
      if (connected && validAddress(address) && (hasV2 || hasV1 || looksLikeSonyHeadphones(displayName))) {
        Candidate candidate{address, displayName.empty() ? "Sony headphones" : displayName, {}};
        if (hasV2 || (!hasV2 && !hasV1)) candidate.services.push_back(MDR_SERVICE_UUID_XM5);
        if (hasV1 || (!hasV2 && !hasV1)) candidate.services.push_back(MDR_SERVICE_UUID_LEGACY);
        candidates.push_back(std::move(candidate));
      }
      dbus_message_iter_next(&interfaces);
    }
    dbus_message_iter_next(&objects);
  }

  std::stable_sort(candidates.begin(), candidates.end(), [](const Candidate& left, const Candidate& right) {
    return left.services.size() < right.services.size();
  });
  if (candidates.empty()) error = "No connected Sony MDR device was found in BlueZ";
  return candidates;
}

std::string getText(MDRHeadphones* headphones, MDRText field) {
  uint32_t size = 0;
  if (mdrHeadphonesGetText(headphones, field, 0, nullptr, &size) != MDR_RESULT_OK || size == 0) return {};
  std::vector<char> value(size);
  if (mdrHeadphonesGetText(headphones, field, 0, value.data(), &size) != MDR_RESULT_OK) return {};
  return value.data();
}

std::string codecName(MDRAudioCodec codec) {
  switch (codec) {
    case MDR_AUDIO_CODEC_SBC: return "sbc";
    case MDR_AUDIO_CODEC_AAC: return "aac";
    case MDR_AUDIO_CODEC_LDAC: return "ldac";
    case MDR_AUDIO_CODEC_APTX: return "aptx";
    case MDR_AUDIO_CODEC_APTX_HD: return "aptx_hd";
    case MDR_AUDIO_CODEC_LC3: return "lc3";
    default: return "unknown";
  }
}

std::string chargingName(MDRChargingState charging) {
  switch (charging) {
    case MDR_CHARGING_NO: return "no";
    case MDR_CHARGING_YES: return "yes";
    case MDR_CHARGING_COMPLETE: return "complete";
    default: return "unknown";
  }
}

std::string noiseName(MDRNoiseMode mode) {
  switch (mode) {
    case MDR_NOISE_MODE_OFF: return "off";
    case MDR_NOISE_MODE_CANCELLING: return "anc";
    case MDR_NOISE_MODE_AMBIENT: return "ambient";
    default: return "unknown";
  }
}

std::string adaptiveName(MDRAdaptiveSensitivity sensitivity) {
  switch (sensitivity) {
    case MDR_ADAPTIVE_SENSITIVITY_LOW: return "low";
    case MDR_ADAPTIVE_SENSITIVITY_STANDARD: return "standard";
    case MDR_ADAPTIVE_SENSITIVITY_HIGH: return "high";
    default: return "unknown";
  }
}

std::string speechSensitivityName(MDRSpeechSensitivity sensitivity) {
  switch (sensitivity) {
    case MDR_SPEECH_SENSITIVITY_AUTO: return "auto";
    case MDR_SPEECH_SENSITIVITY_LOW: return "low";
    case MDR_SPEECH_SENSITIVITY_HIGH: return "high";
    default: return "unknown";
  }
}

std::string speakTimeoutName(MDRSpeakTimeout timeout) {
  switch (timeout) {
    case MDR_SPEAK_TIMEOUT_SHORT: return "short";
    case MDR_SPEAK_TIMEOUT_MEDIUM: return "medium";
    case MDR_SPEAK_TIMEOUT_LONG: return "long";
    case MDR_SPEAK_TIMEOUT_MANUAL: return "manual";
    default: return "unknown";
  }
}

std::string playbackName(MDRPlaybackStatus status) {
  switch (status) {
    case MDR_PLAYBACK_STOPPED: return "stopped";
    case MDR_PLAYBACK_PLAYING: return "playing";
    case MDR_PLAYBACK_PAUSED: return "paused";
    default: return "unknown";
  }
}

std::string dseeName(MDRDSEEType type) {
  switch (type) {
    case MDR_DSEE_STANDARD: return "standard";
    case MDR_DSEE_HX: return "hx";
    case MDR_DSEE_HX_AI: return "hx_ai";
    case MDR_DSEE_ULTIMATE: return "ultimate";
    default: return "unknown";
  }
}

std::string priorityName(MDRAudioPriority priority) {
  switch (priority) {
    case MDR_AUDIO_PRIORITY_QUALITY: return "quality";
    case MDR_AUDIO_PRIORITY_STABILITY: return "stable";
    default: return "unknown";
  }
}

std::string presetName(MDREqualizerPreset preset) {
  static const std::array names{
    "off", "rock", "pop", "jazz", "dance", "edm", "r_and_b_hip_hop", "acoustic", "bright", "excited",
    "mellow", "relaxed", "vocal", "treble", "bass", "speech", "heavy", "clear", "hard", "soft", "gaming",
    "fps_1", "fps_2", "fps_3", "custom", "user_1", "user_2", "user_3", "user_4", "user_5"
  };
  const auto value = static_cast<std::size_t>(preset);
  return value < names.size() ? names[value] : "unknown";
}

std::optional<MDREqualizerPreset> presetValue(const std::string& name) {
  for (uint32_t value = MDR_EQ_OFF; value <= MDR_EQ_USER_5; ++value) {
    if (presetName(static_cast<MDREqualizerPreset>(value)) == name)
      return static_cast<MDREqualizerPreset>(value);
  }
  return std::nullopt;
}

class MdrBackend final : public Backend {
 public:
  explicit MdrBackend(int idleSeconds) : idleDuration_(std::chrono::seconds(idleSeconds)) {
    state_.revision = 1;
    owner_.reset(mdrConnectionLinuxCreate());
    connection_ = owner_ ? mdrConnectionLinuxGet(owner_.get()) : nullptr;
    if (connection_ == nullptr) setError("Could not initialize the libmdr BlueZ backend", false);
  }

  ~MdrBackend() override { closeTransport(); }

  void tick() override {
    const auto now = Clock::now();
    if (stage_ == Stage::Idle) {
      if (wanted_ && connection_ != nullptr && now >= nextAttempt_) beginDiscovery();
      return;
    }
    if (stage_ == Stage::Connecting) {
      const MDRResult result = mdrConnectionPoll(connection_, 0);
      if (result == MDR_RESULT_OK) {
        beginInitialization();
      } else if (result != MDR_RESULT_INPROGRESS && result != MDR_RESULT_ERROR_TIMEOUT) {
        advanceAttempt(result);
      } else if (now >= connectionDeadline_) {
        advanceAttempt(MDR_RESULT_ERROR_TIMEOUT);
      }
      return;
    }

    if (!headphones_) return;
    MDREvent event = MDR_EVENT_NONE;
    const MDRResult pollResult = mdrHeadphonesPoll(headphones_.get(), &event);
    if (pollResult != MDR_RESULT_OK) {
      failConnection("Sony protocol poll failed: " + resultMessage(pollResult));
      return;
    }
    if (event == MDR_EVENT_INITIALIZE_COMPLETE) {
      const MDRResult result = mdrHeadphonesRequestFetch(headphones_.get());
      if (result != MDR_RESULT_OK) {
        failConnection("Could not fetch Sony state: " + resultMessage(result));
        return;
      }
      stage_ = Stage::Syncing;
      setPhase("syncing", {}, false);
    } else if (event == MDR_EVENT_SYNC_COMPLETE) {
      stage_ = Stage::Ready;
      updateSnapshot();
      lastFetch_ = now;
    } else if (event != MDR_EVENT_NONE && mdrHeadphonesIsInitialized(headphones_.get())) {
      updateSnapshot();
    }

    if (stage_ == Stage::Ready && mdrHeadphonesIsReady(headphones_.get())
        && mdrHeadphonesIsDirty(headphones_.get())) {
      const MDRResult result = mdrHeadphonesRequestCommit(headphones_.get());
      if (result != MDR_RESULT_OK) failConnection("Could not commit Sony setting: " + resultMessage(result));
    }
    if (stage_ == Stage::Ready && mdrHeadphonesIsReady(headphones_.get()) && now - lastFetch_ >= 30s) {
      const MDRResult result = mdrHeadphonesRequestFetch(headphones_.get());
      if (result == MDR_RESULT_OK) lastFetch_ = now;
    }
    if (!wanted_ && stage_ == Stage::Ready && now >= idleDeadline_) disconnectIdle();
  }

  ActionResult handle(const Command& command) override {
    const auto now = Clock::now();
    if (command.kind == CommandKind::Status) return {true, {}};
    if (command.kind == CommandKind::PanelOpen) {
      wanted_ = true;
      nextAttempt_ = now;
      if (stage_ == Stage::Idle) setPhase("discovering", {}, false);
      return {true, {}};
    }
    if (command.kind == CommandKind::PanelClose) {
      wanted_ = false;
      idleDeadline_ = now + idleDuration_;
      return {true, {}};
    }
    if (stage_ != Stage::Ready || !headphones_) return {false, "Headphones are not synchronized yet"};
    idleDeadline_ = now + idleDuration_;

    if (command.kind == CommandKind::Refresh) {
      if (!mdrHeadphonesIsReady(headphones_.get())) return {false, "A Sony request is already in progress"};
      const MDRResult result = mdrHeadphonesRequestFetch(headphones_.get());
      return result == MDR_RESULT_OK ? ActionResult{true, {}} : ActionResult{false, resultMessage(result)};
    }

    MDRResult result = MDR_RESULT_ERROR_NOT_SUPPORTED;
    switch (command.kind) {
      case CommandKind::Noise:
      case CommandKind::AmbientLevel:
      case CommandKind::FocusOnVoice: result = setNoise(command); break;
      case CommandKind::SpeakToChat: result = setSpeak(command); break;
      case CommandKind::Dsee:
      case CommandKind::EqualizerPreset: result = setEqualizer(command); break;
      case CommandKind::ConnectionPriority: result = setConnection(command); break;
      case CommandKind::Volume: result = setVolume(command); break;
      case CommandKind::Playback: result = setPlayback(command); break;
      default: break;
    }
    if (result != MDR_RESULT_OK) return {false, resultMessage(result)};
    updateSnapshot();
    return {true, {}};
  }

  const State& state() const override { return state_; }
  bool consumeDirty() override {
    const bool value = dirty_;
    dirty_ = false;
    return value;
  }
  int pollTimeoutMs() const override { return stage_ == Stage::Idle ? 750 : 30; }

 private:
  enum class Stage { Idle, Connecting, Initializing, Syncing, Ready };

  bool available(MDRFeature feature) const {
    MDRFeatureAvailability value = MDR_AVAILABILITY_UNKNOWN;
    return headphones_ && mdrHeadphonesGetFeature(headphones_.get(), feature, &value) == MDR_RESULT_OK
      && value == MDR_AVAILABILITY_AVAILABLE;
  }

  std::string resultMessage(MDRResult result) const {
    if (connection_ != nullptr) {
      const char* detail = mdrConnectionGetLastError(connection_);
      if (detail != nullptr && *detail != '\0') return detail;
    }
    return mdrResultString(result);
  }

  void markChanged() {
    ++state_.revision;
    dirty_ = true;
  }

  void setPhase(std::string phase, std::string error, bool connected) {
    if (state_.phase == phase && state_.lastError == error && state_.connected == connected) return;
    state_.phase = std::move(phase);
    state_.lastError = std::move(error);
    state_.connected = connected;
    markChanged();
  }

  void setError(std::string error, bool retry) {
    setPhase("error", std::move(error), false);
    if (retry) nextAttempt_ = Clock::now() + 3s;
  }

  void beginDiscovery() {
    setPhase("discovering", {}, false);
    std::string error;
    candidates_ = discoverCandidates(error);
    candidateIndex_ = 0;
    serviceIndex_ = 0;
    if (candidates_.empty()) {
      stage_ = Stage::Idle;
      setError(error, true);
      return;
    }
    startAttempt();
  }

  void startAttempt() {
    while (candidateIndex_ < candidates_.size()) {
      Candidate& candidate = candidates_[candidateIndex_];
      while (serviceIndex_ < candidate.services.size()) {
        mdrConnectionDisconnect(connection_);
        const MDRResult result = mdrConnectionConnect(
          connection_, candidate.address.c_str(), candidate.services[serviceIndex_]);
        if (result == MDR_RESULT_OK || result == MDR_RESULT_INPROGRESS) {
          stage_ = Stage::Connecting;
          connectionDeadline_ = Clock::now() + 10s;
          setPhase("connecting", {}, false);
          return;
        }
        ++serviceIndex_;
      }
      ++candidateIndex_;
      serviceIndex_ = 0;
    }
    stage_ = Stage::Idle;
    setError("Could not open a Sony MDR control channel: " + resultMessage(MDR_RESULT_ERROR_NO_CONNECTION), true);
  }

  void advanceAttempt(MDRResult reason) {
    lastTransportError_ = resultMessage(reason);
    mdrConnectionDisconnect(connection_);
    ++serviceIndex_;
    startAttempt();
  }

  void beginInitialization() {
    MDRHeadphones* raw = nullptr;
    const MDRResult createResult = mdrHeadphonesCreate(MDR_ABI_VERSION, connection_, &raw);
    if (createResult != MDR_RESULT_OK || raw == nullptr) {
      advanceAttempt(createResult);
      return;
    }
    headphones_.reset(raw);
    const MDRResult initResult = mdrHeadphonesRequestInit(headphones_.get());
    if (initResult != MDR_RESULT_OK) {
      headphones_.reset();
      advanceAttempt(initResult);
      return;
    }
    stage_ = Stage::Initializing;
    state_.device.name = candidates_[candidateIndex_].name;
    setPhase("syncing", {}, false);
  }

  void closeTransport() {
    headphones_.reset();
    if (connection_ != nullptr) mdrConnectionDisconnect(connection_);
  }

  void failConnection(const std::string& error) {
    closeTransport();
    stage_ = Stage::Idle;
    setError(error, wanted_);
  }

  void disconnectIdle() {
    closeTransport();
    stage_ = Stage::Idle;
    setPhase("idle", {}, false);
  }

  void updateSnapshot() {
    if (!headphones_) return;
    const std::string before = serializeState(state_);
    state_.phase = "ready";
    state_.connected = true;
    state_.lastError.clear();

    MDRModel model{};
    if (mdrHeadphonesGetModel(headphones_.get(), &model) == MDR_RESULT_OK) {
      state_.device.protocol = static_cast<int>(model.protocol_version);
      state_.device.codec = codecName(model.audio_codec);
    }
    const std::string modelName = getText(headphones_.get(), MDR_TEXT_MODEL_NAME);
    if (!modelName.empty()) state_.device.model = modelName;
    state_.device.firmware = getText(headphones_.get(), MDR_TEXT_FIRMWARE_VERSION);

    Capabilities& c = state_.capabilities;
    c.batterySingle = available(MDR_FEATURE_BATTERY_SINGLE);
    c.batteryLeftRight = available(MDR_FEATURE_BATTERY_LEFT_RIGHT);
    c.batteryCase = available(MDR_FEATURE_BATTERY_CASE);
    c.playbackMetadata = available(MDR_FEATURE_PLAYBACK_METADATA);
    c.playbackControl = available(MDR_FEATURE_PLAYBACK_CONTROL);
    c.playbackVolume = available(MDR_FEATURE_PLAYBACK_VOLUME);
    c.noiseCancelling = available(MDR_FEATURE_NOISE_CANCELLING);
    c.ambientSound = available(MDR_FEATURE_AMBIENT_SOUND);
    c.adaptiveAmbientSound = available(MDR_FEATURE_ADAPTIVE_AMBIENT_SOUND);
    c.speakToChat = available(MDR_FEATURE_SPEAK_TO_CHAT);
    c.listeningMode = available(MDR_FEATURE_LISTENING_MODE);
    c.equalizer = available(MDR_FEATURE_EQUALIZER);
    c.dsee = available(MDR_FEATURE_DSEE);
    c.pairedDeviceManagement = available(MDR_FEATURE_PAIRED_DEVICE_MANAGEMENT);
    c.pairingMode = available(MDR_FEATURE_PAIRING_MODE);
    c.generalSettings = available(MDR_FEATURE_GENERAL_SETTINGS);
    c.assignableControls = available(MDR_FEATURE_ASSIGNABLE_CONTROLS);
    c.noiseControlButton = available(MDR_FEATURE_NOISE_CONTROL_BUTTON);
    c.autoPowerOff = available(MDR_FEATURE_AUTO_POWER_OFF);
    c.wearingDetection = available(MDR_FEATURE_WEARING_DETECTION);
    c.autoPause = available(MDR_FEATURE_AUTO_PAUSE);
    c.headGesture = available(MDR_FEATURE_HEAD_GESTURE);
    c.voiceGuidance = available(MDR_FEATURE_VOICE_GUIDANCE);
    c.voiceGuidanceVolume = available(MDR_FEATURE_VOICE_GUIDANCE_VOLUME);
    c.shutdown = available(MDR_FEATURE_SHUTDOWN);
    c.connectionMode = available(MDR_FEATURE_CONNECTION_MODE);
    c.safeListening = available(MDR_FEATURE_SAFE_LISTENING);

    state_.battery = {};
    std::array<MDRBattery, 4> batteries{};
    uint32_t batteryCount = batteries.size();
    if (mdrHeadphonesGetBatteries(headphones_.get(), batteries.data(), &batteryCount) == MDR_RESULT_OK) {
      for (uint32_t index = 0; index < batteryCount && index < batteries.size(); ++index) {
        const MDRBattery& source = batteries[index];
        if (source.part > MDR_BATTERY_CASE) continue;
        state_.battery[source.part] = {
          source.present != MDR_FALSE,
          static_cast<int>(source.level_percent),
          chargingName(source.charging)
        };
      }
    }

    MDRNoiseControl noise{};
    if (mdrHeadphonesGetNoiseControl(headphones_.get(), &noise) == MDR_RESULT_OK) {
      state_.noise = {
        noiseName(noise.mode), static_cast<int>(noise.ambient_level), noise.focus_on_voice != MDR_FALSE,
        noise.adaptive_ambient != MDR_FALSE, adaptiveName(noise.adaptive_sensitivity)
      };
    }
    MDRSpeakToChat speak{};
    if (mdrHeadphonesGetSpeakToChat(headphones_.get(), &speak) == MDR_RESULT_OK) {
      state_.speakToChat = {
        speak.enabled != MDR_FALSE, speechSensitivityName(speak.sensitivity), speakTimeoutName(speak.timeout)
      };
    }
    MDREqualizer equalizer{};
    if (mdrHeadphonesGetEqualizer(headphones_.get(), &equalizer) == MDR_RESULT_OK) {
      state_.equalizer.preset = presetName(equalizer.preset);
      state_.equalizer.clearBass = equalizer.clear_bass;
      state_.equalizer.dseeEnabled = equalizer.dsee_enabled != MDR_FALSE;
      state_.equalizer.dseeType = dseeName(equalizer.dsee_type);
      std::array<int8_t, 16> bands{};
      uint32_t count = bands.size();
      if (mdrHeadphonesGetEqualizerBands(headphones_.get(), bands.data(), &count) == MDR_RESULT_OK) {
        state_.equalizer.bands.clear();
        for (uint32_t index = 0; index < count && index < bands.size(); ++index)
          state_.equalizer.bands.push_back(bands[index]);
      }
    }
    MDRPlayback playback{};
    if (mdrHeadphonesGetPlayback(headphones_.get(), &playback) == MDR_RESULT_OK) {
      state_.playback = {playbackName(playback.status), static_cast<int>(playback.volume)};
    }
    MDRConnectionMode connection{};
    if (mdrHeadphonesGetConnectionMode(headphones_.get(), &connection) == MDR_RESULT_OK)
      state_.connection.priority = priorityName(connection.audio_priority);

    if (serializeState(state_) != before) markChanged();
  }

  MDRResult setNoise(const Command& command) {
    if (!state_.capabilities.noiseCancelling && !state_.capabilities.ambientSound)
      return MDR_RESULT_ERROR_NOT_SUPPORTED;
    MDRNoiseControl value{};
    MDRResult result = mdrHeadphonesGetNoiseControl(headphones_.get(), &value);
    if (result != MDR_RESULT_OK) return result;
    if (command.kind == CommandKind::Noise) {
      value.mode = command.value == "anc" ? MDR_NOISE_MODE_CANCELLING
        : command.value == "ambient" ? MDR_NOISE_MODE_AMBIENT : MDR_NOISE_MODE_OFF;
      if (value.mode == MDR_NOISE_MODE_AMBIENT && value.ambient_level == 0) value.ambient_level = 20;
    } else if (command.kind == CommandKind::AmbientLevel) {
      if (!state_.capabilities.ambientSound) return MDR_RESULT_ERROR_NOT_SUPPORTED;
      value.ambient_level = static_cast<uint8_t>(command.number);
    } else {
      if (!state_.capabilities.ambientSound) return MDR_RESULT_ERROR_NOT_SUPPORTED;
      value.focus_on_voice = command.value == "on" ? MDR_TRUE : MDR_FALSE;
    }
    return mdrHeadphonesSetNoiseControl(headphones_.get(), &value);
  }

  MDRResult setSpeak(const Command& command) {
    if (!state_.capabilities.speakToChat) return MDR_RESULT_ERROR_NOT_SUPPORTED;
    MDRSpeakToChat value{};
    MDRResult result = mdrHeadphonesGetSpeakToChat(headphones_.get(), &value);
    if (result != MDR_RESULT_OK) return result;
    value.enabled = command.value == "on" ? MDR_TRUE : MDR_FALSE;
    return mdrHeadphonesSetSpeakToChat(headphones_.get(), &value);
  }

  MDRResult setEqualizer(const Command& command) {
    if (command.kind == CommandKind::Dsee && !state_.capabilities.dsee) return MDR_RESULT_ERROR_NOT_SUPPORTED;
    if (command.kind == CommandKind::EqualizerPreset && !state_.capabilities.equalizer)
      return MDR_RESULT_ERROR_NOT_SUPPORTED;
    MDREqualizer value{};
    MDRResult result = mdrHeadphonesGetEqualizer(headphones_.get(), &value);
    if (result != MDR_RESULT_OK) return result;
    if (command.kind == CommandKind::Dsee) value.dsee_enabled = command.value == "on" ? MDR_TRUE : MDR_FALSE;
    else {
      const auto preset = presetValue(command.value);
      if (!preset) return MDR_RESULT_ERROR_INVALID_ARGUMENT;
      value.preset = *preset;
    }
    return mdrHeadphonesSetEqualizer(headphones_.get(), &value);
  }

  MDRResult setConnection(const Command& command) {
    if (!state_.capabilities.connectionMode) return MDR_RESULT_ERROR_NOT_SUPPORTED;
    MDRConnectionMode value{};
    value.audio_priority = command.value == "quality" ? MDR_AUDIO_PRIORITY_QUALITY : MDR_AUDIO_PRIORITY_STABILITY;
    return mdrHeadphonesSetConnectionMode(headphones_.get(), &value);
  }

  MDRResult setVolume(const Command& command) {
    if (!state_.capabilities.playbackVolume) return MDR_RESULT_ERROR_NOT_SUPPORTED;
    MDRPlayback value{};
    MDRResult result = mdrHeadphonesGetPlayback(headphones_.get(), &value);
    if (result != MDR_RESULT_OK) return result;
    value.volume = static_cast<uint8_t>(command.number);
    return mdrHeadphonesSetPlayback(headphones_.get(), &value);
  }

  MDRResult setPlayback(const Command& command) {
    if (!state_.capabilities.playbackControl) return MDR_RESULT_ERROR_NOT_SUPPORTED;
    MDRPlaybackCommand value{};
    value.action = command.value == "play" ? MDR_PLAYBACK_PLAY
      : command.value == "pause" ? MDR_PLAYBACK_PAUSE
      : command.value == "next" ? MDR_PLAYBACK_NEXT : MDR_PLAYBACK_PREVIOUS;
    return mdrHeadphonesPlayback(headphones_.get(), &value);
  }

  State state_;
  bool dirty_{true};
  bool wanted_{};
  Stage stage_{Stage::Idle};
  std::chrono::seconds idleDuration_;
  Clock::time_point idleDeadline_{Clock::now()};
  Clock::time_point nextAttempt_{Clock::now()};
  Clock::time_point connectionDeadline_{Clock::now()};
  Clock::time_point lastFetch_{Clock::now()};
  LinuxConnectionPointer owner_;
  MDRConnection* connection_{};
  HeadphonesPointer headphones_;
  std::vector<Candidate> candidates_;
  std::size_t candidateIndex_{};
  std::size_t serviceIndex_{};
  std::string lastTransportError_;
};

}  // namespace

std::unique_ptr<Backend> createMdrBackend(int idleSeconds) { return std::make_unique<MdrBackend>(idleSeconds); }

}  // namespace sony
