#include <string>
#include <vector>

#include <unity.h>

#include "todo/frame.h"

using todo::Reassembler;
using Frames = std::vector<std::vector<uint8_t>>;

void setUp() {}
void tearDown() {}

static int r(Reassembler::Result x) { return (int)x; }

static Frames split(const std::string& m, size_t maxFrame, size_t minFrames) {
  Frames f = todo::splitFrames(m, maxFrame);
  TEST_ASSERT_GREATER_OR_EQUAL_UINT_MESSAGE(minFrames, f.size(), "za mało ramek");
  return f;
}
static Reassembler::Result feed(Reassembler& ra, const std::vector<uint8_t>& f) { return ra.feed(f.data(), f.size()); }

static std::string message(size_t n) {
  std::string s;
  for (size_t i = 0; i < n; i++) s += (char)('a' + i % 26);
  return s;
}

void test_split_respects_max_frame_size_and_numbers_frames() {
  Frames f = todo::splitFrames(message(50), 20);
  TEST_ASSERT_EQUAL_UINT(3, f.size());
  TEST_ASSERT_EQUAL_UINT(20, f[0].size());
  TEST_ASSERT_EQUAL_UINT(20, f[1].size());
  TEST_ASSERT_EQUAL_UINT(19, f[2].size());
  for (size_t i = 0; i < 3; i++) {
    TEST_ASSERT_EQUAL_UINT8(i, f[i][0]);  // seq LE, młodszy bajt
    TEST_ASSERT_EQUAL_UINT8(0, f[i][1]);
  }
  TEST_ASSERT_EQUAL_UINT8(0, f[0][2]);
  TEST_ASSERT_EQUAL_UINT8(0, f[1][2]);
  TEST_ASSERT_EQUAL_UINT8(todo::kFrameLast, f[2][2]);
  TEST_ASSERT_EQUAL_UINT8('a', f[0][3]);
  TEST_ASSERT_EQUAL_UINT8('r', f[1][3]);  // 18. znak
}

void test_empty_message_is_single_header_frame() {
  Frames f = todo::splitFrames("", 20);
  TEST_ASSERT_EQUAL_UINT(1, f.size());
  uint8_t expected[] = {0, 0, todo::kFrameLast};
  TEST_ASSERT_EQUAL_UINT(3, f[0].size());
  TEST_ASSERT_EQUAL_HEX8_ARRAY(expected, f[0].data(), 3);
}

void test_reassembles_frames_in_order() {
  std::string m = message(300);
  Frames f = split(m, 23, 2);
  Reassembler ra;
  for (size_t i = 0; i + 1 < f.size(); i++) TEST_ASSERT_EQUAL_INT(r(Reassembler::Result::Incomplete), r(feed(ra, f[i])));
  TEST_ASSERT_EQUAL_INT(r(Reassembler::Result::Complete), r(feed(ra, f.back())));
  TEST_ASSERT_EQUAL_STRING(m.c_str(), ra.message().c_str());
}

void test_retransmitted_frame_is_ignored() {
  std::string m = message(40);
  Frames f = split(m, 20, 3);
  Reassembler ra;
  feed(ra, f[0]);
  TEST_ASSERT_EQUAL_INT(r(Reassembler::Result::Incomplete), r(feed(ra, f[0])));
  feed(ra, f[1]);
  TEST_ASSERT_EQUAL_INT(r(Reassembler::Result::Complete), r(feed(ra, f[2])));
  TEST_ASSERT_EQUAL_STRING(m.c_str(), ra.message().c_str());
}

void test_gap_in_sequence_is_error_and_resets() {
  std::string m = message(40);
  Frames f = split(m, 20, 3);
  Reassembler ra;
  feed(ra, f[0]);
  TEST_ASSERT_EQUAL_INT(r(Reassembler::Result::Error), r(feed(ra, f[2])));
  feed(ra, f[0]);
  feed(ra, f[1]);
  TEST_ASSERT_EQUAL_INT(r(Reassembler::Result::Complete), r(feed(ra, f[2])));
  TEST_ASSERT_EQUAL_STRING(m.c_str(), ra.message().c_str());
}

void test_message_must_start_at_seq_zero() {
  Frames f = split(message(40), 20, 2);
  Reassembler ra;
  TEST_ASSERT_EQUAL_INT(r(Reassembler::Result::Error), r(feed(ra, f[1])));
}

void test_frame_shorter_than_header_is_error() {
  Reassembler ra;
  uint8_t bad[] = {0, 0};
  TEST_ASSERT_EQUAL_INT(r(Reassembler::Result::Error), r(ra.feed(bad, sizeof bad)));
}

void test_message_over_limit_is_error() {
  Frames f = split(message(todo::kMaxMessageBytes + 1), 512, 2);
  Reassembler ra;
  Reassembler::Result last = Reassembler::Result::Incomplete;
  for (auto& fr : f) {
    last = feed(ra, fr);
    if (last != Reassembler::Result::Incomplete) break;
  }
  TEST_ASSERT_EQUAL_INT(r(Reassembler::Result::Error), r(last));
}

void test_consecutive_messages_each_start_from_zero() {
  Reassembler ra;
  for (const std::string m : {std::string("{\"op\":\"hello\"}"), message(60)}) {
    Frames f = split(m, 20, 1);
    Reassembler::Result last = Reassembler::Result::Incomplete;
    for (auto& fr : f) last = feed(ra, fr);
    TEST_ASSERT_EQUAL_INT(r(Reassembler::Result::Complete), r(last));
    TEST_ASSERT_EQUAL_STRING(m.c_str(), ra.message().c_str());
  }
}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_split_respects_max_frame_size_and_numbers_frames);
  RUN_TEST(test_empty_message_is_single_header_frame);
  RUN_TEST(test_reassembles_frames_in_order);
  RUN_TEST(test_retransmitted_frame_is_ignored);
  RUN_TEST(test_gap_in_sequence_is_error_and_resets);
  RUN_TEST(test_message_must_start_at_seq_zero);
  RUN_TEST(test_frame_shorter_than_header_is_error);
  RUN_TEST(test_message_over_limit_is_error);
  RUN_TEST(test_consecutive_messages_each_start_from_zero);
  return UNITY_END();
}
