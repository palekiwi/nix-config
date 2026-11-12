#pragma once

#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <unistd.h>

inline int32_t stream_audio(const float *samples, int32_t count, float,
                            void *arg) {
  auto &failed = *static_cast<bool *>(arg);
  const char *data = reinterpret_cast<const char *>(samples);
  size_t remaining = count * sizeof(float);
  while (remaining) {
    ssize_t written = write(STDOUT_FILENO, data, remaining);
    if (written < 0 && errno == EINTR) {
      continue;
    }
    if (written <= 0) {
      failed = true;
      return 0;
    }
    data += written;
    remaining -= written;
  }
  return 1;
}
