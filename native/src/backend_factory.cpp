#include "sony/backend.hpp"

namespace sony {

std::unique_ptr<Backend> createBackend(bool mock, int idleSeconds) {
  if (mock) return createMockBackend();
#ifdef SONY_WITH_LIBMDR
  return createMdrBackend(idleSeconds);
#else
  (void)idleSeconds;
  return createNullBackend();
#endif
}

}  // namespace sony
