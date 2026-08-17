#include "sony/backend.hpp"

namespace sony {
namespace {

class NullBackend final : public Backend {
 public:
  NullBackend() {
    state_.revision = 1;
    state_.phase = "error";
    state_.lastError = "Daemon was built without libmdr; rebuild without --without-libmdr for hardware access";
  }

  void tick() override {}
  ActionResult handle(const Command& command) override {
    if (command.kind == CommandKind::Status) return {true, {}};
    return {false, state_.lastError};
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

std::unique_ptr<Backend> createNullBackend() { return std::make_unique<NullBackend>(); }

}  // namespace sony
