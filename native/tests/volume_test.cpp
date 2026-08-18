#include "sony/volume.hpp"

#include <cassert>
#include <cstdlib>
#include <iostream>

int main() {
  assert(sony::mdrVolumeToPercent(-1) == 0);
  assert(sony::mdrVolumeToPercent(0) == 0);
  assert(sony::mdrVolumeToPercent(1) == 3);
  assert(sony::mdrVolumeToPercent(15) == 50);
  assert(sony::mdrVolumeToPercent(29) == 97);
  assert(sony::mdrVolumeToPercent(30) == 100);
  assert(sony::mdrVolumeToPercent(31) == 100);

  assert(sony::percentToMdrVolume(-1) == 0);
  assert(sony::percentToMdrVolume(0) == 0);
  assert(sony::percentToMdrVolume(1) == 0);
  assert(sony::percentToMdrVolume(2) == 1);
  assert(sony::percentToMdrVolume(20) == 6);
  assert(sony::percentToMdrVolume(50) == 15);
  assert(sony::percentToMdrVolume(99) == 30);
  assert(sony::percentToMdrVolume(100) == 30);
  assert(sony::percentToMdrVolume(101) == 30);

  for (int percent = 0; percent <= 100; ++percent) {
    const int canonical = sony::canonicalVolumePercent(percent);
    assert(canonical >= 0);
    assert(canonical <= 100);
    assert(std::abs(canonical - percent) <= 2);
    assert(sony::canonicalVolumePercent(canonical) == canonical);
  }

  std::cout << "volume_test: passed\n";
}
