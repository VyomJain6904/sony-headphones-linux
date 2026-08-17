#include "sony/command.hpp"

#include <cassert>
#include <iostream>

int main() {
  auto parsed = sony::parseCommandLine("noise ambient\n");
  assert(parsed.ok);
  assert(parsed.command.kind == sony::CommandKind::Noise);
  assert(parsed.command.value == "ambient");

  parsed = sony::parseCommandLine("ambient-level 20");
  assert(parsed.ok && parsed.command.number == 20);
  assert(!sony::parseCommandLine("ambient-level 0").ok);
  assert(!sony::parseCommandLine("volume 101").ok);
  assert(!sony::parseCommandLine("eq-preset hacked;command").ok);
  assert(!sony::parseCommandLine("noise anc extra").ok);
  assert(!sony::parseCommandLine(std::string(4097, 'x')).ok);
  std::cout << "command_test: passed\n";
}
