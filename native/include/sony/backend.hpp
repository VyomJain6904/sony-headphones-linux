#pragma once

#include "sony/command.hpp"
#include "sony/state.hpp"

#include <memory>
#include <string>

namespace sony {

struct ActionResult {
  bool ok{};
  std::string message;
};

class Backend {
 public:
  virtual ~Backend() = default;
  virtual void tick() = 0;
  virtual ActionResult handle(const Command& command) = 0;
  virtual const State& state() const = 0;
  virtual bool consumeDirty() = 0;
  virtual int pollTimeoutMs() const = 0;
};

std::unique_ptr<Backend> createBackend(bool mock, int idleSeconds);
std::unique_ptr<Backend> createMockBackend();
std::unique_ptr<Backend> createNullBackend();
#ifdef SONY_WITH_LIBMDR
std::unique_ptr<Backend> createMdrBackend(int idleSeconds);
#endif

}  // namespace sony
