#pragma once

#include <string>

#include <unity.h>

#include "todo/task.h"

inline todo::Task makeTask(const std::string& id, const std::string& owner,
                           todo::Priority priority = todo::Priority::Normal, int64_t dueAt = 0,
                           int64_t createdAt = 1000, int64_t updatedAt = 1000,
                           const std::string& updatedBy = "") {
  todo::Task t;
  t.id = id;
  t.ownerId = owner;
  t.title = "Zadanie " + id;
  t.priority = priority;
  t.dueAt = dueAt;
  t.createdAt = createdAt;
  t.updatedAt = updatedAt;
  t.updatedBy = updatedBy.empty() ? owner : updatedBy;
  return t;
}

inline std::string repeatUtf8(const std::string& s, size_t n) {
  std::string out;
  for (size_t i = 0; i < n; i++) out += s;
  return out;
}

inline void assertTaskEqual(const todo::Task& e, const todo::Task& a) {
  TEST_ASSERT_EQUAL_STRING(e.id.c_str(), a.id.c_str());
  TEST_ASSERT_EQUAL_STRING(e.ownerId.c_str(), a.ownerId.c_str());
  TEST_ASSERT_EQUAL_STRING(e.title.c_str(), a.title.c_str());
  TEST_ASSERT_EQUAL_INT((int)e.priority, (int)a.priority);
  TEST_ASSERT_EQUAL_INT64(e.dueAt, a.dueAt);
  TEST_ASSERT_EQUAL_INT((int)e.status, (int)a.status);
  TEST_ASSERT_EQUAL_INT64(e.reminderAt, a.reminderAt);
  TEST_ASSERT_EQUAL_INT64(e.createdAt, a.createdAt);
  TEST_ASSERT_EQUAL_INT64(e.updatedAt, a.updatedAt);
  TEST_ASSERT_EQUAL_STRING(e.updatedBy.c_str(), a.updatedBy.c_str());
  TEST_ASSERT_EQUAL(e.deleted, a.deleted);
}
