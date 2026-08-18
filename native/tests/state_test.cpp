#include "sony/state.hpp"

#include <cassert>
#include <iostream>

int main() {
  sony::State state;
  state.revision = 9;
  state.phase = "ready";
  state.connected = true;
  state.device.name = "Vyom's \"XM5\"\nHeadset";
  state.battery[0] = {true, 73, "no"};
  state.capabilities.noiseCancelling = true;
  state.equalizer.availablePresets = {"bright", "bass"};
  state.equalizer.bands = {-2, 0, 2};
  const std::string json = sony::serializeState(state);

  assert(json.find("\"schema_version\":1") != std::string::npos);
  assert(json.find("\"revision\":9") != std::string::npos);
  assert(json.find("Vyom's \\\"XM5\\\"\\nHeadset") != std::string::npos);
  assert(json.find("\"noise_cancelling\":true") != std::string::npos);
  assert(json.find("\"available_presets\":[\"bright\",\"bass\"]") != std::string::npos);
  assert(json.find("\"bands\":[-2,0,2]") != std::string::npos);
  assert(json.back() == '\n');
  std::cout << "state_test: passed\n";
}
