#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

namespace todo {

enum class Priority : uint8_t { Low = 0, Normal = 1, High = 2 };
enum class Status : uint8_t { Active = 0, Done = 1 };

constexpr size_t kMaxTitleBytes = 120;  // UTF-8, ta sama granica w aplikacji iOS
constexpr size_t kMaxTasks = 256;       // łącznie z tombstone'ami

// Czasy w milisekundach od epoki Unix (UTC), ustawiane przez telefon. 0 = brak.
struct Task {
  std::string id;  // UUID nadany przez telefon
  std::string ownerId;
  std::string title;
  Priority priority = Priority::Normal;
  int64_t dueAt = 0;
  Status status = Status::Active;
  int64_t reminderAt = 0;  // urządzenie tylko przechowuje i oddaje dalej
  int64_t createdAt = 0;
  int64_t updatedAt = 0;
  std::string updatedBy;  // userId autora ostatniej zmiany
  bool deleted = false;   // tombstone
};

// Last-writer-wins: true, gdy `incoming` ma nowszy updatedAt, a przy remisie większy updatedBy
// (porównanie bajtowe). Ten sam (updatedAt, updatedBy) to ta sama wersja, więc false.
bool wins(const Task& incoming, const Task& current);

}  // namespace todo
