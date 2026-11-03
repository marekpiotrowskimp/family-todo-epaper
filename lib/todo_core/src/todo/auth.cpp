#include "auth.h"

#include <cstring>

#include "bytes.h"

namespace todo {

namespace {

// SHA-256 wg FIPS 180-4.
class Sha256 {
 public:
  Sha256() { reset(); }

  void reset() {
    static const uint32_t init[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                                     0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
    memcpy(h_, init, sizeof h_);
    len_ = 0;
    fill_ = 0;
  }

  void update(const uint8_t* d, size_t n) {
    for (size_t i = 0; i < n; i++) {
      block_[fill_++] = d[i];
      if (fill_ == 64) {
        compress();
        fill_ = 0;
      }
    }
    len_ += n;
  }

  Digest finish() {
    uint64_t bits = len_ * 8;
    uint8_t pad = 0x80;
    update(&pad, 1);
    uint8_t zero = 0;
    while (fill_ != 56) update(&zero, 1);
    uint8_t lenBytes[8];
    for (int i = 0; i < 8; i++) lenBytes[i] = (uint8_t)(bits >> (56 - 8 * i));
    update(lenBytes, 8);
    Digest out;
    for (int i = 0; i < 8; i++)
      for (int k = 0; k < 4; k++) out[4 * i + k] = (uint8_t)(h_[i] >> (24 - 8 * k));
    return out;
  }

 private:
  static uint32_t rotr(uint32_t x, int n) { return (x >> n) | (x << (32 - n)); }

  void compress() {
    static const uint32_t k[64] = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};
    uint32_t w[64];
    for (int i = 0; i < 16; i++)
      w[i] = (uint32_t)block_[4 * i] << 24 | (uint32_t)block_[4 * i + 1] << 16 |
             (uint32_t)block_[4 * i + 2] << 8 | block_[4 * i + 3];
    for (int i = 16; i < 64; i++) {
      uint32_t s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      uint32_t s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    uint32_t a = h_[0], b = h_[1], c = h_[2], d = h_[3], e = h_[4], f = h_[5], g = h_[6], h = h_[7];
    for (int i = 0; i < 64; i++) {
      uint32_t t1 = h + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + ((e & f) ^ (~e & g)) + k[i] + w[i];
      uint32_t t2 = (rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c));
      h = g;
      g = f;
      f = e;
      e = d + t1;
      d = c;
      c = b;
      b = a;
      a = t1 + t2;
    }
    h_[0] += a;
    h_[1] += b;
    h_[2] += c;
    h_[3] += d;
    h_[4] += e;
    h_[5] += f;
    h_[6] += g;
    h_[7] += h;
  }

  uint32_t h_[8];
  uint8_t block_[64];
  size_t fill_;
  uint64_t len_;
};

const uint8_t kMagic[4] = {'T', 'D', 'M', '2'};  // TDM1 zawierał sekrety parowania

}  // namespace

Digest hmacSha256(const uint8_t* key, size_t keyLen, const uint8_t* msg, size_t msgLen) {
  uint8_t k[64] = {0};
  if (keyLen > 64) {
    Sha256 kh;
    kh.update(key, keyLen);
    Digest d = kh.finish();
    memcpy(k, d.data(), d.size());
  } else {
    memcpy(k, key, keyLen);
  }
  uint8_t ipad[64], opad[64];
  for (int i = 0; i < 64; i++) {
    ipad[i] = k[i] ^ 0x36;
    opad[i] = k[i] ^ 0x5c;
  }
  Sha256 inner;
  inner.update(ipad, 64);
  inner.update(msg, msgLen);
  Digest innerDigest = inner.finish();
  Sha256 outer;
  outer.update(opad, 64);
  outer.update(innerDigest.data(), innerDigest.size());
  return outer.finish();
}

Digest authMac(const Secret& secret, const Nonce& nonce, const std::string& userId) {
  std::vector<uint8_t> msg(nonce.begin(), nonce.end());
  msg.insert(msg.end(), userId.begin(), userId.end());
  return hmacSha256(secret.data(), secret.size(), msg.data(), msg.size());
}

AddMemberResult MemberRegistry::add(const Member& m) {
  AddMemberResult result = AddMemberResult::Added;
  for (auto it = members_.begin(); it != members_.end(); ++it) {
    if (it->userId != m.userId) continue;
    members_.erase(it);  // wraca na koniec jako ostatnio widziany
    result = AddMemberResult::Replaced;
    break;
  }
  if (result == AddMemberResult::Added && members_.size() >= kMaxMembers) {
    members_.erase(members_.begin());  // najdawniej widziany
    result = AddMemberResult::Evicted;
  }
  members_.push_back(m);
  return result;
}

const Member* MemberRegistry::find(const std::string& userId) const {
  for (auto& m : members_)
    if (m.userId == userId) return &m;
  return nullptr;
}

size_t MemberRegistry::size() const { return members_.size(); }

std::vector<uint8_t> MemberRegistry::serialize() const {
  detail::Writer w;
  w.raw(kMagic, sizeof kMagic);
  w.u8((uint8_t)members_.size());
  for (auto& m : members_) {
    w.str(m.userId);
    w.str(m.displayName);
  }
  return w.finish();
}

bool MemberRegistry::deserialize(const std::vector<uint8_t>& data, MemberRegistry& out) {
  out = MemberRegistry();
  if (!detail::checkCrc(data, sizeof kMagic)) return false;
  detail::Reader r(data.data(), data.size() - 4);
  uint8_t magic[4];
  r.raw(magic, sizeof magic);
  if (!r.ok() || memcmp(magic, kMagic, sizeof magic) != 0) return false;
  uint8_t count = r.u8();
  if (!r.ok() || count > kMaxMembers) return false;
  MemberRegistry reg;
  for (uint8_t i = 0; i < count; i++) {
    Member m;
    m.userId = r.str();
    m.displayName = r.str();
    if (!r.ok()) return false;
    reg.members_.push_back(m);
  }
  if (!r.atEnd()) return false;
  out = std::move(reg);
  return true;
}

}  // namespace todo
