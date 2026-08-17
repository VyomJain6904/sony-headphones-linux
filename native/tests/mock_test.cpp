#include "sony/backend.hpp"

#include <cassert>
#include <iostream>

int main() {
  auto backend = sony::createMockBackend();
  assert(backend->state().connected);
  assert(backend->state().noise.mode == "anc");
  assert(backend->consumeDirty());
  assert(!backend->consumeDirty());

  sony::Command command{sony::CommandKind::Noise, "ambient", 0};
  assert(backend->handle(command).ok);
  assert(backend->state().noise.mode == "ambient");
  assert(backend->consumeDirty());

  command = {sony::CommandKind::Volume, {}, 63};
  assert(backend->handle(command).ok);
  assert(backend->state().playback.volume == 63);
  std::cout << "mock_test: passed\n";
}
