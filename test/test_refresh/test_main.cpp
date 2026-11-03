#include <unity.h>

#include "todo/refresh.h"

using todo::kRotateMs;
using todo::kSettleMs;
using todo::RefreshScheduler;

void setUp() {}
void tearDown() {}

void test_first_check_after_boot_refreshes_once() {
  RefreshScheduler s;
  TEST_ASSERT_TRUE(s.due(0, 1));
  TEST_ASSERT_EQUAL_UINT(0, s.currentPage());
  TEST_ASSERT_FALSE(s.due(1000, 1));
}

void test_data_change_refreshes_after_settle_time() {
  RefreshScheduler s;
  s.due(0, 1);
  s.onDataChanged(10000);
  TEST_ASSERT_FALSE(s.due(10000 + kSettleMs - 1, 1));
  TEST_ASSERT_TRUE(s.due(10000 + kSettleMs, 1));
  TEST_ASSERT_FALSE(s.due(10000 + kSettleMs + 1, 1));
}

void test_further_changes_extend_settle_time() {
  RefreshScheduler s;
  s.due(0, 1);
  s.onDataChanged(10000);
  s.onDataChanged(12000);
  TEST_ASSERT_FALSE(s.due(10000 + kSettleMs, 1));
  TEST_ASSERT_TRUE(s.due(12000 + kSettleMs, 1));
}

void test_multiple_pages_rotate_every_rotate_interval() {
  RefreshScheduler s;
  TEST_ASSERT_TRUE(s.due(0, 3));
  TEST_ASSERT_EQUAL_UINT(0, s.currentPage());
  TEST_ASSERT_FALSE(s.due(kRotateMs - 1, 3));
  TEST_ASSERT_TRUE(s.due(kRotateMs, 3));
  TEST_ASSERT_EQUAL_UINT(1, s.currentPage());
  TEST_ASSERT_TRUE(s.due(2 * kRotateMs, 3));
  TEST_ASSERT_EQUAL_UINT(2, s.currentPage());
  TEST_ASSERT_TRUE(s.due(3 * kRotateMs, 3));
  TEST_ASSERT_EQUAL_UINT(0, s.currentPage());
}

void test_single_page_is_not_refreshed_periodically() {
  RefreshScheduler s;
  TEST_ASSERT_TRUE(s.due(0, 1));
  TEST_ASSERT_FALSE(s.due(10 * kRotateMs, 1));
}

void test_page_is_clamped_when_page_count_shrinks() {
  RefreshScheduler s;
  s.due(0, 3);
  s.due(kRotateMs, 3);
  s.due(2 * kRotateMs, 3);
  TEST_ASSERT_EQUAL_UINT(2, s.currentPage());
  s.onDataChanged(2 * kRotateMs + 10);
  TEST_ASSERT_TRUE(s.due(2 * kRotateMs + 10 + kSettleMs, 1));
  TEST_ASSERT_EQUAL_UINT(0, s.currentPage());
}

void test_millis_wraparound_is_handled() {
  RefreshScheduler s;
  TEST_ASSERT_TRUE(s.due(0xFFFFF000u, 1));
  s.onDataChanged(0xFFFFFF00u);
  uint32_t settled = 0xFFFFFF00u + kSettleMs;  // przepełnia się do 0x00000AB8
  TEST_ASSERT_FALSE(s.due(settled - 1, 1));
  TEST_ASSERT_TRUE(s.due(settled, 1));
}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_first_check_after_boot_refreshes_once);
  RUN_TEST(test_data_change_refreshes_after_settle_time);
  RUN_TEST(test_further_changes_extend_settle_time);
  RUN_TEST(test_multiple_pages_rotate_every_rotate_interval);
  RUN_TEST(test_single_page_is_not_refreshed_periodically);
  RUN_TEST(test_page_is_clamped_when_page_count_shrinks);
  RUN_TEST(test_millis_wraparound_is_handled);
  return UNITY_END();
}
