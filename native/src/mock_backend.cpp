#include "sony/backend.hpp"

#include <algorithm>

namespace sony {
namespace {

class MockBackend final : public Backend {
 public:
  MockBackend() {
    state_.revision = 1;
    state_.phase = "ready";
    state_.connected = true;
    state_.device = {"Vyom's WH-1000XM5", "WH-1000XM5", "mock-2.3.1", 2, "ldac"};
    state_.battery[0] = {true, 73, "no"};
    Capabilities& c = state_.capabilities;
    c.batterySingle = true;
    c.playbackMetadata = true;
    c.playbackControl = true;
    c.playbackVolume = true;
    c.noiseCancelling = true;
    c.ambientSound = true;
    c.adaptiveAmbientSound = true;
    c.speakToChat = true;
    c.equalizer = true;
    c.dsee = true;
    c.connectionMode = true;
    c.autoPowerOff = true;
    c.wearingDetection = true;
    c.autoPause = true;
    state_.noise = {"anc", 10, false, false, "standard"};
    state_.speakToChat = {false, "auto", "medium"};
    state_.equalizer = {"bright", 2, {-2, -1, 0, 1, 2}, true, "ultimate"};
    state_.playback = {"playing", 42};
    state_.connection = {"quality"};
  }

  void tick() override {}

  ActionResult handle(const Command& command) override {
    switch (command.kind) {
      case CommandKind::Status:
      case CommandKind::PanelOpen:
      case CommandKind::PanelClose:
      case CommandKind::Refresh:
        return {true, {}};
      case CommandKind::Noise:
        state_.noise.mode = command.value;
        break;
      case CommandKind::AmbientLevel:
        state_.noise.ambientLevel = command.number;
        break;
      case CommandKind::FocusOnVoice:
        state_.noise.focusOnVoice = command.value == "on";
        break;
      case CommandKind::SpeakToChat:
        state_.speakToChat.enabled = command.value == "on";
        break;
      case CommandKind::Dsee:
        state_.equalizer.dseeEnabled = command.value == "on";
        break;
      case CommandKind::EqualizerPreset:
        state_.equalizer.preset = command.value;
        break;
      case CommandKind::ConnectionPriority:
        state_.connection.priority = command.value;
        break;
      case CommandKind::Volume:
        state_.playback.volume = std::clamp(command.number, 0, 100);
        break;
      case CommandKind::Playback:
        if (command.value == "play") state_.playback.status = "playing";
        else if (command.value == "pause") state_.playback.status = "paused";
        break;
    }
    ++state_.revision;
    dirty_ = true;
    return {true, {}};
  }

  const State& state() const override { return state_; }
  bool consumeDirty() override {
    const bool value = dirty_;
    dirty_ = false;
    return value;
  }
  int pollTimeoutMs() const override { return 1000; }

 private:
  State state_;
  bool dirty_{true};
};

}  // namespace

std::unique_ptr<Backend> createMockBackend() { return std::make_unique<MockBackend>(); }

}  // namespace sony
