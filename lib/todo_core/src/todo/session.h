#pragma once

#include <functional>
#include <string>

#include "auth.h"
#include "store.h"

namespace todo {

constexpr size_t kMaxBatch = 20;  // maks. zadań w jednym push i jednej stronie pull

// Protokół synchronizacji na poziomie wiadomości JSON (jedna wiadomość = jedna złożona
// sekwencja ramek BLE). Żądania i odpowiedzi opisuje README, sekcja „Protokół BLE”.
// Każde hello rozpoczyna nową sesję z nowym nonce i kasuje uwierzytelnienie. Nie ma parowania:
// telefon znający klucz rodziny przedstawia się w auth i trafia do rejestru członków.
class SyncSession {
 public:
  using RandomFn = std::function<void(uint8_t* out, size_t len)>;

  // familyKey: wspólny klucz aplikacji i firmware (include/family_key.h).
  SyncSession(TaskStore& store, MemberRegistry& members, const Secret& familyKey, RandomFn random);

  std::string handle(const std::string& requestJson);
  // Odpowiedź na wiadomość, której ramek nie dało się złożyć: {"ok":false,"err":"bad_frame"}.
  static std::string frameErrorResponse();

  bool authenticated() const;
  // true, gdy od ostatniego wywołania przyjęto jakąkolwiek zmianę zadań; zeruje flagę.
  bool takeDataChanged();

 private:
  TaskStore& store_;
  MemberRegistry& members_;
  Secret family_key_;
  RandomFn random_;
  Nonce nonce_{};
  bool has_nonce_ = false;
  std::string user_;
  bool data_changed_ = false;
};

}  // namespace todo
