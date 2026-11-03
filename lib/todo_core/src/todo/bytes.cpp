#include "bytes.h"

namespace todo {
namespace detail {

uint32_t crc32(const uint8_t* data, size_t len) {
  uint32_t crc = 0xFFFFFFFFu;
  for (size_t i = 0; i < len; i++) {
    crc ^= data[i];
    for (int k = 0; k < 8; k++) crc = (crc >> 1) ^ (0xEDB88320u & (0u - (crc & 1u)));
  }
  return ~crc;
}

bool checkCrc(const std::vector<uint8_t>& data, size_t minPayload) {
  if (data.size() < minPayload + 4) return false;
  size_t n = data.size() - 4;
  uint32_t stored = 0;
  for (int i = 0; i < 4; i++) stored |= (uint32_t)data[n + i] << (8 * i);
  return stored == crc32(data.data(), n);
}

std::string toHex(const uint8_t* d, size_t n) {
  static const char* digits = "0123456789abcdef";
  std::string s;
  s.reserve(n * 2);
  for (size_t i = 0; i < n; i++) {
    s += digits[d[i] >> 4];
    s += digits[d[i] & 0x0F];
  }
  return s;
}

static int nibble(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

bool fromHex(const std::string& hex, uint8_t* out, size_t n) {
  if (hex.size() != n * 2) return false;
  for (size_t i = 0; i < n; i++) {
    int hi = nibble(hex[2 * i]), lo = nibble(hex[2 * i + 1]);
    if (hi < 0 || lo < 0) return false;
    out[i] = (uint8_t)(hi << 4 | lo);
  }
  return true;
}

}  // namespace detail
}  // namespace todo
