#include <string>
#include <vector>

#include <unity.h>

#include "../helpers/fixtures.h"
#include "todo/display.h"

using todo::Priority;
using todo::selectForDisplay;

void setUp() {}
void tearDown() {}

static void assertIds(const std::vector<std::string>& expected, const todo::DisplayPage& p) {
  TEST_ASSERT_EQUAL_UINT_MESSAGE(expected.size(), p.items.size(), "liczba pozycji");
  for (size_t i = 0; i < expected.size(); i++)
    TEST_ASSERT_EQUAL_STRING(expected[i].c_str(), p.items[i].id.c_str());
}

void test_global_order_priority_then_due_then_created_then_id() {
  std::vector<todo::Task> ts = {
      makeTask("l_due", "anna", Priority::Low, 500),
      makeTask("n_nodue_new", "anna", Priority::Normal, 0, 200),
      makeTask("h_nodue", "anna", Priority::High, 0),
      makeTask("n_nodue_old_b", "anna", Priority::Normal, 0, 100),
      makeTask("h_due2", "anna", Priority::High, 2000),
      makeTask("n_due1", "anna", Priority::Normal, 1000),
      makeTask("n_nodue_old", "anna", Priority::Normal, 0, 100),
      makeTask("h_due1", "anna", Priority::High, 1000),
  };
  auto p = selectForDisplay(ts, 10, 0);
  assertIds({"h_due1", "h_due2", "h_nodue", "n_due1", "n_nodue_old", "n_nodue_old_b",
             "n_nodue_new", "l_due"},
            p);
  TEST_ASSERT_TRUE(todo::displayBefore(ts[7], ts[4]));   // h_due1 przed h_due2
  TEST_ASSERT_FALSE(todo::displayBefore(ts[4], ts[7]));
}

void test_only_active_not_deleted_tasks_are_shown() {
  auto done = makeTask("done", "anna", Priority::High);
  done.status = todo::Status::Done;
  auto gone = makeTask("gone", "anna", Priority::High);
  gone.deleted = true;
  auto p = selectForDisplay({done, gone, makeTask("live", "anna", Priority::Low)}, 8, 0);
  assertIds({"live"}, p);
}

void test_every_owner_gets_at_least_one_row() {
  std::vector<todo::Task> ts;
  for (int i = 1; i <= 5; i++) ts.push_back(makeTask("a" + std::to_string(i), "anna", Priority::High, 1000 * i));
  ts.push_back(makeTask("b1", "bartek", Priority::Low));
  ts.push_back(makeTask("c1", "celina", Priority::Normal));
  auto p = selectForDisplay(ts, 3, 0);
  assertIds({"a1", "c1", "b1"}, p);
  TEST_ASSERT_EQUAL_UINT(1, p.pageCount);
}

void test_remaining_rows_are_filled_in_global_order() {
  std::vector<todo::Task> ts = {
      makeTask("b2", "bartek", Priority::Low, 2000), makeTask("a3", "anna", Priority::High, 3000),
      makeTask("b1", "bartek", Priority::Low, 1000), makeTask("a1", "anna", Priority::High, 1000),
      makeTask("a2", "anna", Priority::High, 2000),
  };
  auto p = selectForDisplay(ts, 4, 0);
  assertIds({"a1", "a2", "a3", "b1"}, p);
}

void test_owner_with_only_finished_tasks_does_not_take_a_row() {
  auto bDone = makeTask("b1", "bartek", Priority::High);
  bDone.status = todo::Status::Done;
  std::vector<todo::Task> ts = {makeTask("a1", "anna", Priority::Normal, 1000),
                                makeTask("a2", "anna", Priority::Normal, 2000),
                                makeTask("a3", "anna", Priority::Normal, 3000), bDone};
  auto p = selectForDisplay(ts, 2, 0);
  assertIds({"a1", "a2"}, p);
  TEST_ASSERT_EQUAL_UINT(1, p.pageCount);
}

void test_more_owners_than_rows_rotates_pages_of_owners() {
  std::vector<todo::Task> ts = {
      makeTask("e1", "ewa", Priority::Low, 1000),      makeTask("a1", "anna", Priority::High, 1000),
      makeTask("a2", "anna", Priority::High, 2000),    makeTask("c1", "celina", Priority::Normal, 1000),
      makeTask("b1", "bartek", Priority::High, 5000),  makeTask("d1", "dawid", Priority::Normal, 0),
  };
  // Kolejność osób wg najlepszego zadania: anna(a1), bartek(b1), celina(c1), dawid(d1), ewa(e1)
  auto p0 = selectForDisplay(ts, 2, 0);
  TEST_ASSERT_EQUAL_UINT(3, p0.pageCount);
  TEST_ASSERT_EQUAL_UINT(0, p0.page);
  assertIds({"a1", "b1"}, p0);
  auto p1 = selectForDisplay(ts, 2, 1);
  assertIds({"c1", "d1"}, p1);
  auto p2 = selectForDisplay(ts, 2, 2);
  assertIds({"e1"}, p2);  // ostatnia strona bez dopełniania
  auto p3 = selectForDisplay(ts, 2, 3);
  TEST_ASSERT_EQUAL_UINT(0, p3.page);
  assertIds({"a1", "b1"}, p3);
}

void test_empty_list_gives_single_empty_page() {
  auto p = selectForDisplay({}, todo::kScreenRows, 5);
  TEST_ASSERT_EQUAL_UINT(0, p.items.size());
  TEST_ASSERT_EQUAL_UINT(1, p.pageCount);
  TEST_ASSERT_EQUAL_UINT(0, p.page);
}

void test_screen_has_nine_rows_without_header() { TEST_ASSERT_EQUAL_UINT(9, todo::kScreenRows); }

void test_nine_owners_fit_on_single_page() {
  std::vector<todo::Task> ts;
  for (int i = 0; i < 9; i++) ts.push_back(makeTask("t" + std::to_string(i), "u" + std::to_string(i)));
  auto p = selectForDisplay(ts, todo::kScreenRows, 0);
  TEST_ASSERT_EQUAL_UINT(9, p.items.size());
  TEST_ASSERT_EQUAL_UINT(1, p.pageCount);
}

// --- Wyśrodkowanie listy w pionie (ekran 300 px, wiersz 33 px) ---

void test_screen_geometry_constants() {
  TEST_ASSERT_EQUAL_INT(300, todo::kScreenHeight);
  TEST_ASSERT_EQUAL_INT(33, todo::kRowHeight);
  TEST_ASSERT_EQUAL_INT(16, todo::kPageLabelHeight);
}

void test_single_row_is_centered_vertically() {
  TEST_ASSERT_EQUAL_INT(133, todo::listTop(1));  // (300 - 33) / 2; środek wiersza 149,5
  TEST_ASSERT_EQUAL_INT(133, todo::rowTop(0, 1));
}

void test_list_top_for_each_row_count() {
  const int expected[] = {150, 133, 117, 100, 84, 67, 51, 34, 18, 1};  // (300 - n·33) / 2
  for (size_t n = 0; n <= todo::kScreenRows; n++) TEST_ASSERT_EQUAL_INT_MESSAGE(expected[n], todo::listTop(n), "listTop(n)");
}

void test_space_above_and_below_differs_by_at_most_one_pixel() {
  for (size_t n = 1; n <= todo::kScreenRows; n++) {
    int above = todo::listTop(n);
    int below = todo::kScreenHeight - (todo::rowTop(n - 1, n) + todo::kRowHeight);
    TEST_ASSERT_TRUE_MESSAGE(below - above == 0 || below - above == 1, "symetria");
  }
}

void test_rows_follow_each_other_without_gaps() {
  TEST_ASSERT_EQUAL_INT(67, todo::rowTop(0, 5));
  TEST_ASSERT_EQUAL_INT(100, todo::rowTop(1, 5));
  TEST_ASSERT_EQUAL_INT(199, todo::rowTop(4, 5));
  TEST_ASSERT_EQUAL_INT(1, todo::rowTop(0, 9));
  TEST_ASSERT_EQUAL_INT(265, todo::rowTop(8, 9));  // dół 298, mieści się w 300
}

void test_more_rows_than_screen_is_treated_as_full_screen() {
  TEST_ASSERT_EQUAL_INT(1, todo::listTop(12));
  TEST_ASSERT_EQUAL_INT(1, todo::rowTop(0, 12));
}

void test_only_row_overlapping_bottom_strip_reserves_page_label() {
  TEST_ASSERT_TRUE(todo::rowReservesPageLabel(8, 9));   // dół 298 > 284
  TEST_ASSERT_FALSE(todo::rowReservesPageLabel(7, 9));  // dół 265
  TEST_ASSERT_FALSE(todo::rowReservesPageLabel(7, 8));  // 8 wierszy: dół 282 <= 284
  TEST_ASSERT_FALSE(todo::rowReservesPageLabel(0, 1));  // pojedynczy wiersz na środku
  TEST_ASSERT_FALSE(todo::rowReservesPageLabel(2, 3));
}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_global_order_priority_then_due_then_created_then_id);
  RUN_TEST(test_only_active_not_deleted_tasks_are_shown);
  RUN_TEST(test_every_owner_gets_at_least_one_row);
  RUN_TEST(test_remaining_rows_are_filled_in_global_order);
  RUN_TEST(test_owner_with_only_finished_tasks_does_not_take_a_row);
  RUN_TEST(test_more_owners_than_rows_rotates_pages_of_owners);
  RUN_TEST(test_empty_list_gives_single_empty_page);
  RUN_TEST(test_screen_has_nine_rows_without_header);
  RUN_TEST(test_nine_owners_fit_on_single_page);
  RUN_TEST(test_screen_geometry_constants);
  RUN_TEST(test_single_row_is_centered_vertically);
  RUN_TEST(test_list_top_for_each_row_count);
  RUN_TEST(test_space_above_and_below_differs_by_at_most_one_pixel);
  RUN_TEST(test_rows_follow_each_other_without_gaps);
  RUN_TEST(test_more_rows_than_screen_is_treated_as_full_screen);
  RUN_TEST(test_only_row_overlapping_bottom_strip_reserves_page_label);
  return UNITY_END();
}
