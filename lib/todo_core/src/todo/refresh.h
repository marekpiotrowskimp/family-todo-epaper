#pragma once

#include <cstddef>
#include <cstdint>

namespace todo {

constexpr uint32_t kSettleMs = 3000;         // odczekanie po ostatniej zmianie (seria push)
constexpr uint32_t kRotateMs = 5 * 60 * 1000;  // zmiana strony, gdy pageCount > 1

// Decyduje, kiedy odświeżyć e-paper. Czas z millis(), odporne na przepełnienie uint32.
class RefreshScheduler {
 public:
  void onDataChanged(uint32_t nowMs);
  // true = odśwież teraz ekran stroną currentPage(). Po true scheduler uznaje odświeżenie
  // za wykonane. Pierwsze wywołanie po starcie zawsze zwraca true.
  bool due(uint32_t nowMs, size_t pageCount);
  size_t currentPage() const;

 private:
  bool started_ = false;
  bool dirty_ = false;
  uint32_t changed_at_ = 0;
  uint32_t last_refresh_ = 0;
  size_t page_ = 0;
};

}  // namespace todo
