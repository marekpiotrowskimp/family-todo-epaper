#pragma once

// Wewnętrzne narzędzia biblioteki: zapis/odczyt formatu trwałego (LE + CRC32) i hex.

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace todo {
namespace detail {

uint32_t crc32(const uint8_t* data, size_t len);

class Writer {
 public:
  void u8(uint8_t v) { out_.push_back(v); }
  void u16(uint16_t v) {
    for (int i = 0; i < 2; i++) out_.push_back((uint8_t)(v >> (8 * i)));
  }
  void u32(uint32_t v) {
    for (int i = 0; i < 4; i++) out_.push_back((uint8_t)(v >> (8 * i)));
  }
  void i64(int64_t v) {
    uint64_t u = (uint64_t)v;
    for (int i = 0; i < 8; i++) out_.push_back((uint8_t)(u >> (8 * i)));
  }
  void str(const std::string& s) {
    u16((uint16_t)s.size());
    out_.insert(out_.end(), s.begin(), s.end());
  }
  void raw(const uint8_t* d, size_t n) { out_.insert(out_.end(), d, d + n); }
  // Dopisuje CRC32 całej dotychczasowej zawartości i oddaje bufor.
  std::vector<uint8_t> finish() {
    u32(crc32(out_.data(), out_.size()));
    return std::move(out_);
  }

 private:
  std::vector<uint8_t> out_;
};

// Czyta bufor bez sumy kontrolnej (sprawdzanej wcześniej przez checkCrc). Każdy odczyt poza
// końcem ustawia ok() == false i zwraca zero.
class Reader {
 public:
  Reader(const uint8_t* d, size_t n) : d_(d), n_(n) {}
  bool ok() const { return ok_; }
  bool atEnd() const { return pos_ == n_; }
  uint8_t u8() { return need(1) ? d_[pos_++] : 0; }
  uint16_t u16() {
    if (!need(2)) return 0;
    uint16_t v = (uint16_t)(d_[pos_] | (d_[pos_ + 1] << 8));
    pos_ += 2;
    return v;
  }
  uint32_t u32() {
    if (!need(4)) return 0;
    uint32_t v = 0;
    for (int i = 0; i < 4; i++) v |= (uint32_t)d_[pos_ + i] << (8 * i);
    pos_ += 4;
    return v;
  }
  int64_t i64() {
    if (!need(8)) return 0;
    uint64_t v = 0;
    for (int i = 0; i < 8; i++) v |= (uint64_t)d_[pos_ + i] << (8 * i);
    pos_ += 8;
    return (int64_t)v;
  }
  std::string str() {
    uint16_t len = u16();
    if (!need(len)) return "";
    std::string s((const char*)d_ + pos_, len);
    pos_ += len;
    return s;
  }
  void raw(uint8_t* out, size_t n) {
    if (!need(n)) return;
    for (size_t i = 0; i < n; i++) out[i] = d_[pos_ + i];
    pos_ += n;
  }

 private:
  bool need(size_t k) {
    if (!ok_ || n_ - pos_ < k) {
      ok_ = false;
      return false;
    }
    return true;
  }
  const uint8_t* d_;
  size_t n_;
  size_t pos_ = 0;
  bool ok_ = true;
};

// true, gdy dane mają co najmniej `minPayload` bajtów treści i poprawne CRC32 na końcu.
bool checkCrc(const std::vector<uint8_t>& data, size_t minPayload);

std::string toHex(const uint8_t* d, size_t n);
// false, gdy `hex` nie ma dokładnie 2*n znaków hex.
bool fromHex(const std::string& hex, uint8_t* out, size_t n);

}  // namespace detail
}  // namespace todo
