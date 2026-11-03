#pragma once

#include <cstddef>
#include <vector>

#include "task.h"

namespace todo {

constexpr size_t kScreenRows = 9;  // 9 × 33 px, bez nagłówka

// Globalna kolejność: priorytet malejąco, zadania z terminem przed zadaniami bez terminu,
// termin rosnąco, createdAt rosnąco, id rosnąco.
bool displayBefore(const Task& a, const Task& b);

struct DisplayPage {
  std::vector<Task> items;  // w globalnej kolejności
  size_t page;              // numer pokazanej strony (page % pageCount)
  size_t pageCount;         // >= 1
};

// Wybór aktywnych zadań na ekran z gwarancją reprezentacji każdego właściciela.
// U <= rows: najlepsze zadanie każdej osoby + dopełnienie globalną kolejnością, jedna strona.
// U > rows:  strony po `rows` osób (osoby w kolejności ich najlepszego zadania), po jednym
//            zadaniu na osobę, bez dopełniania; pageCount = ceil(U / rows).
DisplayPage selectForDisplay(const std::vector<Task>& tasks, size_t rows, size_t page);

}  // namespace todo
