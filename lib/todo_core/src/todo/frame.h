#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace todo {

// Ramka BLE: [seq: uint16 LE][flags: uint8, bit0 = ostatnia][payload].
// Wiadomość zaczyna się od seq 0, kolejne ramki mają seq + 1.
constexpr size_t kFrameHeaderBytes = 3;
constexpr uint8_t kFrameLast = 0x01;
constexpr size_t kMaxMessageBytes = 16 * 1024;

// Dzieli wiadomość na ramki o rozmiarze <= maxFrameBytes (z nagłówkiem). Pusta wiadomość
// to jedna ramka z samym nagłówkiem i flagą kFrameLast.
std::vector<std::vector<uint8_t>> splitFrames(const std::string& message, size_t maxFrameBytes);

class Reassembler {
 public:
  enum class Result : uint8_t { Incomplete, Complete, Error };

  // Error: ramka krótsza niż nagłówek, luka w seq, nowa wiadomość nie od seq 0
  // albo przekroczenie kMaxMessageBytes. Po Error stan jest czyszczony.
  // Powtórzona ostatnio przyjęta ramka (retransmisja) jest ignorowana: Incomplete.
  Result feed(const uint8_t* data, size_t len);
  const std::string& message() const;  // ważne po Complete
  void reset();

 private:
  std::string buffer_;
  std::string message_;
  int32_t last_seq_ = -1;
};

}  // namespace todo
