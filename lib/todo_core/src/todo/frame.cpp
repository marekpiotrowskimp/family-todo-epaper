#include "frame.h"

namespace todo {

std::vector<std::vector<uint8_t>> splitFrames(const std::string& message, size_t maxFrameBytes) {
  std::vector<std::vector<uint8_t>> frames;
  if (maxFrameBytes <= kFrameHeaderBytes) return frames;
  size_t chunk = maxFrameBytes - kFrameHeaderBytes;
  size_t pos = 0;
  uint16_t seq = 0;
  do {
    size_t n = message.size() - pos < chunk ? message.size() - pos : chunk;
    bool last = pos + n == message.size();
    std::vector<uint8_t> f;
    f.reserve(kFrameHeaderBytes + n);
    f.push_back((uint8_t)(seq & 0xFF));
    f.push_back((uint8_t)(seq >> 8));
    f.push_back(last ? kFrameLast : 0);
    f.insert(f.end(), message.begin() + pos, message.begin() + pos + n);
    frames.push_back(std::move(f));
    pos += n;
    seq++;
  } while (pos < message.size());
  return frames;
}

Reassembler::Result Reassembler::feed(const uint8_t* data, size_t len) {
  if (len < kFrameHeaderBytes) {
    reset();
    return Result::Error;
  }
  int32_t seq = data[0] | (data[1] << 8);
  if (last_seq_ < 0) {
    if (seq != 0) {
      reset();
      return Result::Error;
    }
  } else if (seq == last_seq_) {
    return Result::Incomplete;  // retransmisja
  } else if (seq != last_seq_ + 1) {
    reset();
    return Result::Error;
  }
  if (buffer_.size() + (len - kFrameHeaderBytes) > kMaxMessageBytes) {
    reset();
    return Result::Error;
  }
  buffer_.append((const char*)data + kFrameHeaderBytes, len - kFrameHeaderBytes);
  last_seq_ = seq;
  if (!(data[2] & kFrameLast)) return Result::Incomplete;
  message_ = std::move(buffer_);
  buffer_.clear();
  last_seq_ = -1;
  return Result::Complete;
}

const std::string& Reassembler::message() const { return message_; }

void Reassembler::reset() {
  buffer_.clear();
  last_seq_ = -1;
}

}  // namespace todo
