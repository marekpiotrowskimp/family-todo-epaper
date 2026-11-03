#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace todo {

using Digest = std::array<uint8_t, 32>;
using Secret = std::array<uint8_t, 32>;
using Nonce = std::array<uint8_t, 16>;

constexpr size_t kMaxMembers = 8;
constexpr size_t kMaxNameBytes = 32;  // UTF-8, nazwa pokazywana na ekranie

Digest hmacSha256(const uint8_t* key, size_t keyLen, const uint8_t* msg, size_t msgLen);

// Dowód znajomości klucza rodziny: HMAC-SHA256(key, nonce || UTF-8(userId)).
Digest authMac(const Secret& secret, const Nonce& nonce, const std::string& userId);

struct Member {
  std::string userId;
  std::string displayName;  // pokazywane na e-paperze
};

enum class AddMemberResult : uint8_t { Added, Replaced, Evicted };

// Telefony, które się przedstawiły (bez parowania). Kolejność = od najdawniej do ostatnio
// widzianego: add() przenosi osobę na koniec i podmienia nazwę; przy pełnym rejestrze
// usuwa osobę najdawniej widzianą (Evicted).
class MemberRegistry {
 public:
  AddMemberResult add(const Member& m);
  const Member* find(const std::string& userId) const;
  size_t size() const;

  std::vector<uint8_t> serialize() const;
  static bool deserialize(const std::vector<uint8_t>& data, MemberRegistry& out);

 private:
  std::vector<Member> members_;
};

}  // namespace todo
