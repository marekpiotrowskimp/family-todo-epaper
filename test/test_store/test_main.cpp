#include <unity.h>

#include "../helpers/fixtures.h"
#include "todo/store.h"

using todo::Priority;
using todo::TaskStore;
using todo::UpsertResult;

void setUp() {}
void tearDown() {}

static int r(UpsertResult x) { return (int)x; }

void test_inserts_new_task_and_bumps_revision() {
  TaskStore s("S1");
  auto t = makeTask("t1", "anna");
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Inserted), r(s.upsert(t)));
  TEST_ASSERT_EQUAL_UINT(1, s.size());
  TEST_ASSERT_EQUAL_UINT32(1, s.revision());
  TEST_ASSERT_NOT_NULL(s.find("t1"));
  assertTaskEqual(t, *s.find("t1"));
}

void test_newer_version_replaces_stored_one() {
  TaskStore s("S1");
  s.upsert(makeTask("t1", "anna", Priority::Normal, 0, 1000, 1000));
  auto v2 = makeTask("t1", "anna", Priority::High, 0, 1000, 2000, "bartek");
  v2.title = "Nowy tytuł";
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Updated), r(s.upsert(v2)));
  TEST_ASSERT_EQUAL_UINT(1, s.size());
  TEST_ASSERT_EQUAL_UINT32(2, s.revision());
  assertTaskEqual(v2, *s.find("t1"));
}

void test_older_version_is_ignored() {
  TaskStore s("S1");
  auto v2 = makeTask("t1", "anna", Priority::Normal, 0, 1000, 2000);
  v2.title = "Wersja 2";
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Inserted), r(s.upsert(v2)));
  auto v1 = makeTask("t1", "anna", Priority::Normal, 0, 1000, 1000);
  v1.title = "Wersja 1";
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Ignored), r(s.upsert(v1)));
  TEST_ASSERT_EQUAL_STRING("Wersja 2", s.find("t1")->title.c_str());
  TEST_ASSERT_EQUAL_UINT32(1, s.revision());
}

void test_retrying_same_version_creates_no_duplicate() {
  TaskStore s("S1");
  auto t = makeTask("t1", "anna");
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Inserted), r(s.upsert(t)));
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Ignored), r(s.upsert(t)));
  TEST_ASSERT_EQUAL_UINT(1, s.size());
  TEST_ASSERT_EQUAL_UINT32(1, s.revision());
}

void test_concurrent_edits_converge_regardless_of_arrival_order() {
  auto byAnna = makeTask("t1", "anna", Priority::Normal, 0, 1000, 5000, "anna");
  byAnna.title = "od Anny";
  auto byBartek = makeTask("t1", "anna", Priority::Normal, 0, 1000, 5000, "bartek");
  byBartek.title = "od Bartka";
  TaskStore a("A"), b("B");
  a.upsert(byAnna);
  a.upsert(byBartek);
  b.upsert(byBartek);
  b.upsert(byAnna);
  TEST_ASSERT_NOT_NULL(a.find("t1"));
  TEST_ASSERT_NOT_NULL(b.find("t1"));
  TEST_ASSERT_EQUAL_STRING("od Bartka", a.find("t1")->title.c_str());
  TEST_ASSERT_EQUAL_STRING("od Bartka", b.find("t1")->title.c_str());
}

void test_tombstone_blocks_older_edit_but_newer_edit_restores() {
  TaskStore s("S1");
  s.upsert(makeTask("t1", "anna", Priority::Normal, 0, 1000, 1000));
  auto del = makeTask("t1", "anna", Priority::Normal, 0, 1000, 2000);
  del.deleted = true;
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Updated), r(s.upsert(del)));
  TEST_ASSERT_TRUE(s.find("t1")->deleted);

  auto staleEdit = makeTask("t1", "anna", Priority::High, 0, 1000, 1500, "bartek");
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Ignored), r(s.upsert(staleEdit)));
  TEST_ASSERT_TRUE(s.find("t1")->deleted);

  auto laterEdit = makeTask("t1", "anna", Priority::High, 0, 1000, 3000, "bartek");
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Updated), r(s.upsert(laterEdit)));
  TEST_ASSERT_FALSE(s.find("t1")->deleted);
  TEST_ASSERT_EQUAL_UINT32(3, s.revision());
}

void test_changes_since_returns_versions_after_cursor_in_rev_order() {
  TaskStore s("S1");
  s.upsert(makeTask("a", "anna", Priority::Normal, 0, 1000, 1000));   // rev 1
  s.upsert(makeTask("b", "bartek", Priority::Normal, 0, 1000, 1000)); // rev 2
  s.upsert(makeTask("a", "anna", Priority::Normal, 0, 1000, 2000));   // rev 3, a przesuwa się

  auto c = s.changesSince(1, 20);
  TEST_ASSERT_EQUAL_UINT(2, c.size());
  TEST_ASSERT_EQUAL_STRING("b", c[0].task.id.c_str());
  TEST_ASSERT_EQUAL_UINT32(2, c[0].rev);
  TEST_ASSERT_EQUAL_STRING("a", c[1].task.id.c_str());
  TEST_ASSERT_EQUAL_UINT32(3, c[1].rev);
  TEST_ASSERT_EQUAL_INT64(2000, c[1].task.updatedAt);

  auto limited = s.changesSince(0, 1);
  TEST_ASSERT_EQUAL_UINT(1, limited.size());
  TEST_ASSERT_EQUAL_STRING("b", limited[0].task.id.c_str());

  TEST_ASSERT_EQUAL_UINT(0, s.changesSince(3, 20).size());
}

void test_invalid_tasks_are_rejected() {
  TaskStore s("S1");
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Inserted), r(s.upsert(makeTask("ok", "anna"))));

  auto noId = makeTask("", "anna");
  auto noOwner = makeTask("x1", "");
  noOwner.updatedBy = "anna";
  auto emptyTitle = makeTask("x2", "anna");
  emptyTitle.title = "";
  auto longTitle = makeTask("x3", "anna");
  longTitle.title = repeatUtf8("ą", 60) + "a";  // 121 bajtów
  auto noTime = makeTask("x4", "anna", Priority::Normal, 0, 1000, 0);
  auto noAuthor = makeTask("x5", "anna");
  noAuthor.updatedBy = "";

  TEST_ASSERT_EQUAL_INT(r(UpsertResult::RejectedInvalid), r(s.upsert(noId)));
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::RejectedInvalid), r(s.upsert(noOwner)));
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::RejectedInvalid), r(s.upsert(emptyTitle)));
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::RejectedInvalid), r(s.upsert(longTitle)));
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::RejectedInvalid), r(s.upsert(noTime)));
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::RejectedInvalid), r(s.upsert(noAuthor)));
  TEST_ASSERT_EQUAL_UINT(1, s.size());
  TEST_ASSERT_EQUAL_UINT32(1, s.revision());
}

void test_title_limit_is_inclusive_and_tombstone_may_have_empty_title() {
  TaskStore s("S1");
  auto maxTitle = makeTask("m", "anna");
  maxTitle.title = repeatUtf8("ą", 60);  // dokładnie 120 bajtów
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Inserted), r(s.upsert(maxTitle)));
  auto tomb = makeTask("d", "anna");
  tomb.title = "";
  tomb.deleted = true;
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Inserted), r(s.upsert(tomb)));
}

static void fill(TaskStore& s, size_t n) {
  for (size_t i = 0; i < n; i++) s.upsert(makeTask("t" + std::to_string(i), "anna"));
}

void test_full_store_rejects_new_ids_but_accepts_updates() {
  TaskStore s("S1");
  fill(s, todo::kMaxTasks);
  TEST_ASSERT_EQUAL_UINT(todo::kMaxTasks, s.size());
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::RejectedFull), r(s.upsert(makeTask("new", "anna"))));
  auto upd = makeTask("t7", "anna", Priority::High, 0, 1000, 9000);
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Updated), r(s.upsert(upd)));
  TEST_ASSERT_EQUAL_UINT(todo::kMaxTasks, s.size());
  TEST_ASSERT_NULL(s.find("new"));
}

void test_full_store_evicts_oldest_tombstone_for_new_task() {
  TaskStore s("S1");
  fill(s, todo::kMaxTasks);
  auto d5 = makeTask("t5", "anna", Priority::Normal, 0, 1000, 2000);
  d5.deleted = true;
  auto d9 = makeTask("t9", "anna", Priority::Normal, 0, 1000, 2000);
  d9.deleted = true;
  s.upsert(d5);  // starszy tombstone (niższy rev)
  s.upsert(d9);
  TEST_ASSERT_EQUAL_INT(r(UpsertResult::Inserted), r(s.upsert(makeTask("new", "anna"))));
  TEST_ASSERT_NULL(s.find("t5"));
  TEST_ASSERT_NOT_NULL(s.find("t9"));
  TEST_ASSERT_NOT_NULL(s.find("new"));
  TEST_ASSERT_EQUAL_UINT(todo::kMaxTasks, s.size());
}

static TaskStore sampleStore() {
  TaskStore s("S1-7f3a");
  auto a = makeTask("a", "anna", Priority::High, 1793520000000, 1793430000000, 1793433600000, "bartek");
  a.title = "Kupić mleko";
  a.status = todo::Status::Done;
  a.reminderAt = 1793516400000;
  auto b = makeTask("b", "bartek");
  b.deleted = true;
  s.upsert(a);
  s.upsert(b);
  return s;
}

void test_persistence_round_trip_keeps_everything() {
  TaskStore src = sampleStore();
  TaskStore dst;
  TEST_ASSERT_TRUE(TaskStore::deserialize(src.serialize(), dst));
  TEST_ASSERT_EQUAL_STRING("S1-7f3a", dst.storeId().c_str());
  TEST_ASSERT_EQUAL_UINT32(2, dst.revision());
  TEST_ASSERT_EQUAL_UINT(2, dst.size());
  assertTaskEqual(*src.find("a"), *dst.find("a"));
  assertTaskEqual(*src.find("b"), *dst.find("b"));
  auto c = dst.changesSince(0, 20);
  TEST_ASSERT_EQUAL_UINT(2, c.size());
  TEST_ASSERT_EQUAL_UINT32(1, c[0].rev);
  TEST_ASSERT_EQUAL_UINT32(2, c[1].rev);
}

void test_corrupted_persistence_is_rejected_and_leaves_store_empty() {
  auto bytes = sampleStore().serialize();
  TaskStore ok;
  TEST_ASSERT_TRUE(TaskStore::deserialize(bytes, ok));  // kontrola

  auto flipped = bytes;
  flipped[flipped.size() / 2] ^= 0x5A;
  TaskStore a;
  TEST_ASSERT_FALSE(TaskStore::deserialize(flipped, a));
  TEST_ASSERT_EQUAL_UINT(0, a.size());
  TEST_ASSERT_EQUAL_UINT32(0, a.revision());

  auto truncated = std::vector<uint8_t>(bytes.begin(), bytes.begin() + bytes.size() - 5);
  TaskStore b;
  TEST_ASSERT_FALSE(TaskStore::deserialize(truncated, b));
  TEST_ASSERT_EQUAL_UINT(0, b.size());

  TaskStore c;
  TEST_ASSERT_FALSE(TaskStore::deserialize({}, c));
}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_inserts_new_task_and_bumps_revision);
  RUN_TEST(test_newer_version_replaces_stored_one);
  RUN_TEST(test_older_version_is_ignored);
  RUN_TEST(test_retrying_same_version_creates_no_duplicate);
  RUN_TEST(test_concurrent_edits_converge_regardless_of_arrival_order);
  RUN_TEST(test_tombstone_blocks_older_edit_but_newer_edit_restores);
  RUN_TEST(test_changes_since_returns_versions_after_cursor_in_rev_order);
  RUN_TEST(test_invalid_tasks_are_rejected);
  RUN_TEST(test_title_limit_is_inclusive_and_tombstone_may_have_empty_title);
  RUN_TEST(test_full_store_rejects_new_ids_but_accepts_updates);
  RUN_TEST(test_full_store_evicts_oldest_tombstone_for_new_task);
  RUN_TEST(test_persistence_round_trip_keeps_everything);
  RUN_TEST(test_corrupted_persistence_is_rejected_and_leaves_store_empty);
  return UNITY_END();
}
