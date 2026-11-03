#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "task.h"

namespace todo {

enum class UpsertResult : uint8_t { Inserted, Updated, Ignored, RejectedFull, RejectedInvalid };

struct StoredTask {
  Task task;
  uint32_t rev;  // wartość revision() w chwili przyjęcia tej wersji
};

// Lista zadań urządzenia. Każda przyjęta zmiana (Inserted/Updated) zwiększa revision o 1,
// dzięki czemu telefon pobiera tylko zmiany od swojego kursora.
class TaskStore {
 public:
  explicit TaskStore(std::string storeId = "");

  UpsertResult upsert(const Task& t);
  const Task* find(const std::string& id) const;
  size_t size() const;  // łącznie z tombstone'ami
  uint32_t revision() const;
  const std::string& storeId() const;
  std::vector<Task> all() const;
  // Wersje z rev > since, rosnąco po rev, najwyżej `limit` sztuk.
  std::vector<StoredTask> changesSince(uint32_t since, size_t limit) const;

  // Format trwały (flash) z sumą kontrolną. deserialize zwraca false dla uszkodzonych danych
  // i wtedy zostawia `out` puste (size() == 0, revision() == 0).
  std::vector<uint8_t> serialize() const;
  static bool deserialize(const std::vector<uint8_t>& data, TaskStore& out);

 private:
  std::string store_id_;
  uint32_t revision_ = 0;
  std::vector<StoredTask> tasks_;
};

}  // namespace todo
