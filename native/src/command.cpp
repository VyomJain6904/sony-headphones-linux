#include "sony/command.hpp"

#include <charconv>
#include <sstream>
#include <unordered_set>

namespace sony {
namespace {

ParseResult failure(std::string message) { return {false, {}, std::move(message)}; }
ParseResult success(CommandKind kind, std::string value = {}, int number = 0) {
  return {true, {kind, std::move(value), number}, {}};
}

bool parseInteger(const std::string& text, int& value) {
  const char* begin = text.data();
  const char* end = begin + text.size();
  const auto result = std::from_chars(begin, end, value);
  return result.ec == std::errc{} && result.ptr == end;
}

bool oneOf(const std::string& value, const std::unordered_set<std::string>& choices) {
  return choices.contains(value);
}

}  // namespace

ParseResult parseCommand(const std::vector<std::string>& words) {
  if (words.empty()) return failure("no command supplied");
  const std::string& verb = words[0];
  if (verb == "status" && words.size() == 1) return success(CommandKind::Status);
  if (verb == "panel-open" && words.size() == 1) return success(CommandKind::PanelOpen);
  if (verb == "panel-close" && words.size() == 1) return success(CommandKind::PanelClose);
  if (verb == "refresh" && words.size() == 1) return success(CommandKind::Refresh);

  if (verb == "noise" && words.size() == 2) {
    static const std::unordered_set<std::string> modes{"off", "anc", "ambient"};
    return oneOf(words[1], modes) ? success(CommandKind::Noise, words[1]) : failure("noise must be off, anc, or ambient");
  }
  if (verb == "ambient-level" && words.size() == 2) {
    int level = 0;
    if (!parseInteger(words[1], level) || level < 1 || level > 20) return failure("ambient-level must be an integer from 1 to 20");
    return success(CommandKind::AmbientLevel, {}, level);
  }
  if ((verb == "focus-on-voice" || verb == "speak-to-chat" || verb == "dsee") && words.size() == 2) {
    if (words[1] != "on" && words[1] != "off") return failure(verb + " must be on or off");
    const CommandKind kind = verb == "focus-on-voice" ? CommandKind::FocusOnVoice
      : verb == "speak-to-chat" ? CommandKind::SpeakToChat : CommandKind::Dsee;
    return success(kind, words[1]);
  }
  if (verb == "eq-preset" && words.size() == 2) {
    static const std::unordered_set<std::string> presets{
      "off", "rock", "pop", "jazz", "dance", "edm", "r_and_b_hip_hop", "acoustic", "bright",
      "excited", "mellow", "relaxed", "vocal", "treble", "bass", "speech", "heavy", "clear", "hard",
      "soft", "gaming", "fps_1", "fps_2", "fps_3", "custom", "user_1", "user_2", "user_3", "user_4", "user_5"
    };
    return oneOf(words[1], presets) ? success(CommandKind::EqualizerPreset, words[1]) : failure("unknown equalizer preset");
  }
  if (verb == "connection" && words.size() == 2) {
    if (words[1] != "quality" && words[1] != "stable") return failure("connection must be quality or stable");
    return success(CommandKind::ConnectionPriority, words[1]);
  }
  if (verb == "volume" && words.size() == 2) {
    int volume = 0;
    if (!parseInteger(words[1], volume) || volume < 0 || volume > 100) return failure("volume must be an integer from 0 to 100");
    return success(CommandKind::Volume, {}, volume);
  }
  if (verb == "playback" && words.size() == 2) {
    static const std::unordered_set<std::string> actions{"play", "pause", "next", "previous"};
    return oneOf(words[1], actions) ? success(CommandKind::Playback, words[1]) : failure("playback must be play, pause, next, or previous");
  }
  return failure("invalid command or argument count");
}

ParseResult parseCommandLine(const std::string& line) {
  if (line.size() > 4096U) return failure("command exceeds 4096 bytes");
  std::istringstream stream(line);
  std::vector<std::string> words;
  std::string word;
  while (stream >> word) words.push_back(word);
  return parseCommand(words);
}

std::string commandUsage() {
  return
    "commands:\n"
    "  status\n  panel-open\n  panel-close\n  refresh\n"
    "  noise off|anc|ambient\n  ambient-level 1..20\n"
    "  focus-on-voice on|off\n  speak-to-chat on|off\n  dsee on|off\n"
    "  eq-preset <preset>\n  connection quality|stable\n"
    "  volume 0..100\n  playback play|pause|next|previous\n";
}

}  // namespace sony
