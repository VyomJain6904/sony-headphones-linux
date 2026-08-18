#pragma once

#include <algorithm>

namespace sony {

inline constexpr int kMdrVolumeMaximum = 30;
inline constexpr int kVolumePercentMaximum = 100;

constexpr int mdrVolumeToPercent(int level) {
  const int clamped = std::clamp(level, 0, kMdrVolumeMaximum);
  return (clamped * kVolumePercentMaximum + kMdrVolumeMaximum / 2) / kMdrVolumeMaximum;
}

constexpr int percentToMdrVolume(int percent) {
  const int clamped = std::clamp(percent, 0, kVolumePercentMaximum);
  return (clamped * kMdrVolumeMaximum + kVolumePercentMaximum / 2) / kVolumePercentMaximum;
}

constexpr int canonicalVolumePercent(int percent) {
  return mdrVolumeToPercent(percentToMdrVolume(percent));
}

}  // namespace sony
