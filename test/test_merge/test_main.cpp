#include <unity.h>

#include "../helpers/fixtures.h"
#include "todo/task.h"

using todo::wins;

void setUp() {}
void tearDown() {}

void test_newer_updated_at_wins() {
  auto older = makeTask("t1", "anna", todo::Priority::Normal, 0, 1000, 1000, "anna");
  auto newer = makeTask("t1", "anna", todo::Priority::Normal, 0, 1000, 2000, "anna");
  TEST_ASSERT_TRUE(wins(newer, older));
  TEST_ASSERT_FALSE(wins(older, newer));
}

void test_tie_on_updated_at_is_broken_by_greater_updated_by() {
  auto byAnna = makeTask("t1", "anna", todo::Priority::Normal, 0, 1000, 5000, "anna");
  auto byBartek = makeTask("t1", "anna", todo::Priority::Normal, 0, 1000, 5000, "bartek");
  TEST_ASSERT_TRUE(wins(byBartek, byAnna));
  TEST_ASSERT_FALSE(wins(byAnna, byBartek));
}

void test_same_version_does_not_win() {
  auto v = makeTask("t1", "anna", todo::Priority::Normal, 0, 1000, 5000, "anna");
  auto next = makeTask("t1", "anna", todo::Priority::Normal, 0, 1000, 5001, "anna");
  TEST_ASSERT_TRUE(wins(next, v));  // kontrola: funkcja w ogóle rozróżnia wersje
  TEST_ASSERT_FALSE(wins(v, v));
}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_newer_updated_at_wins);
  RUN_TEST(test_tie_on_updated_at_is_broken_by_greater_updated_by);
  RUN_TEST(test_same_version_does_not_win);
  return UNITY_END();
}
