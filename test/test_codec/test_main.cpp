#include <string>

#include <unity.h>

#include "../helpers/fixtures.h"
#include "todo/codec.h"

void setUp() {}
void tearDown() {}

// Wspólne z iOS (TaskWireTests).
static const char* kFullJson =
    "{\"id\":\"0b6f2c1e-3d4a-4c5b-9e8f-1a2b3c4d5e6f\",\"owner\":\"anna\",\"title\":\"Kupić mleko\","
    "\"prio\":2,\"due\":1793520000000,\"status\":\"done\",\"rem\":1793516400000,"
    "\"created\":1793430000000,\"updated\":1793433600000,\"by\":\"bartek\",\"del\":false}";
static const char* kMinimalJson =
    "{\"id\":\"t-2\",\"owner\":\"bartek\",\"title\":\"Wynieść śmieci\",\"prio\":0,"
    "\"status\":\"active\",\"created\":1000,\"updated\":2000,\"by\":\"bartek\",\"del\":true}";

static todo::Task fullTask() {
  todo::Task t;
  t.id = "0b6f2c1e-3d4a-4c5b-9e8f-1a2b3c4d5e6f";
  t.ownerId = "anna";
  t.title = "Kupić mleko";
  t.priority = todo::Priority::High;
  t.dueAt = 1793520000000;
  t.status = todo::Status::Done;
  t.reminderAt = 1793516400000;
  t.createdAt = 1793430000000;
  t.updatedAt = 1793433600000;
  t.updatedBy = "bartek";
  return t;
}

static todo::Task minimalTask() {
  todo::Task t;
  t.id = "t-2";
  t.ownerId = "bartek";
  t.title = "Wynieść śmieci";
  t.priority = todo::Priority::Low;
  t.createdAt = 1000;
  t.updatedAt = 2000;
  t.updatedBy = "bartek";
  t.deleted = true;
  return t;
}

void test_encodes_full_task_exactly() {
  TEST_ASSERT_EQUAL_STRING(kFullJson, todo::encodeTask(fullTask()).c_str());
}

void test_encoding_omits_absent_due_and_reminder() {
  TEST_ASSERT_EQUAL_STRING(kMinimalJson, todo::encodeTask(minimalTask()).c_str());
}

void test_decodes_full_task() {
  todo::Task t;
  TEST_ASSERT_TRUE(todo::decodeTask(kFullJson, t));
  assertTaskEqual(fullTask(), t);
}

void test_decodes_task_without_due_and_reminder() {
  todo::Task t;
  t.dueAt = 99;
  t.reminderAt = 99;
  TEST_ASSERT_TRUE(todo::decodeTask(kMinimalJson, t));
  assertTaskEqual(minimalTask(), t);
}

void test_rejects_malformed_tasks() {
  todo::Task t;
  TEST_ASSERT_TRUE(todo::decodeTask(kFullJson, t));  // kontrola
  TEST_ASSERT_FALSE(todo::decodeTask("{\"owner\":\"a\",\"title\":\"x\",\"prio\":1,\"status\":\"active\","
                                     "\"created\":1,\"updated\":1,\"by\":\"a\",\"del\":false}", t));
  TEST_ASSERT_FALSE(todo::decodeTask("{\"id\":\"x\",\"owner\":\"a\",\"title\":\"x\",\"prio\":3,\"status\":\"active\","
                                     "\"created\":1,\"updated\":1,\"by\":\"a\",\"del\":false}", t));
  TEST_ASSERT_FALSE(todo::decodeTask("{\"id\":\"x\",\"owner\":\"a\",\"title\":\"x\",\"prio\":1,\"status\":\"later\","
                                     "\"created\":1,\"updated\":1,\"by\":\"a\",\"del\":false}", t));
  TEST_ASSERT_FALSE(todo::decodeTask("to nie json", t));
}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_encodes_full_task_exactly);
  RUN_TEST(test_encoding_omits_absent_due_and_reminder);
  RUN_TEST(test_decodes_full_task);
  RUN_TEST(test_decodes_task_without_due_and_reminder);
  RUN_TEST(test_rejects_malformed_tasks);
  return UNITY_END();
}
