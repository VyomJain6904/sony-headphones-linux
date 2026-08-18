#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace sony {

enum class CommandKind : std::uint8_t {
  Status,
  PanelOpen,
  PanelClose,
  Refresh,
  Noise,
  AmbientLevel,
  FocusOnVoice,
  SpeakToChat,
  Dsee,
  EqualizerPreset,
  ConnectionPriority,
  Volume,
  Playback,
};

struct Command {
  CommandKind kind{CommandKind::Status};
  std::string value;
  int number{};
};

struct ParseResult {
  bool ok{};
  Command command;
  std::string error;
};

ParseResult parseCommand(const std::vector<std::string>& words);
ParseResult parseCommandLine(const std::string& line);
std::string commandUsage();

}  // namespace sony
