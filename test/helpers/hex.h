#pragma once

#include <cstdint>
#include <cstdio>
#include <string>

inline std::string toHex(const uint8_t* d, size_t n) {
  std::string s;
  char b[3];
  for (size_t i = 0; i < n; i++) {
    snprintf(b, sizeof b, "%02x", d[i]);
    s += b;
  }
  return s;
}

template <typename A>
inline std::string toHex(const A& a) {
  return toHex(a.data(), a.size());
}

// Wspólne wektory z testami iOS (DeviceAuthTests): sekret 00..1f, nonce a0..af.
inline todo::Secret vectorSecret() {
  todo::Secret s{};
  for (size_t i = 0; i < s.size(); i++) s[i] = (uint8_t)i;
  return s;
}
