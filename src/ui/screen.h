#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "todo/task.h"

struct ScreenRow {
  std::string owner;  // nazwa członka rodziny; pusta, gdy osoby nie ma w rejestrze
  std::string title;
  todo::Priority priority;
  int64_t dueAt;  // ms UTC, 0 = bez terminu
};

struct ScreenState {
  std::vector<ScreenRow> rows;  // już wybrane i uporządkowane (todo::selectForDisplay)
  size_t page;
  size_t pageCount;
};

void screenBegin();
void screenDraw(const ScreenState& s);  // pełne odświeżenie całego ekranu
