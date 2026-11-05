#pragma once

#include <cstddef>
#include <vector>

#include "task.h"

namespace todo {

constexpr size_t kScreenRows = 9;  // 9 × 33 px, bez nagłówka
constexpr int kScreenHeight = 300;
constexpr int kRowHeight = 33;
constexpr int kPageLabelHeight = 16;  // numer strony „1/2” w prawym dolnym rogu

// Górna krawędź pierwszego wiersza: lista `rowCount` wierszy jest wyśrodkowana w pionie
// (reszta z dzielenia idzie w dół). rowCount > kScreenRows liczy się jak kScreenRows.
int listTop(size_t rowCount);

// Górna krawędź wiersza `index` z `rowCount` wierszy.
int rowTop(size_t index, size_t rowCount);

// true, gdy wiersz zachodzi na pas numeru strony (dolne kPageLabelHeight px ekranu)
// i musi zostawić miejsce na numer z prawej.
bool rowReservesPageLabel(size_t index, size_t rowCount);

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
