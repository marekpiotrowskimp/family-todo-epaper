#pragma once

#include <cstddef>
#include <cstdint>

#include "task.h"

namespace todo {

constexpr int16_t kPriorityIconSize = 18;
constexpr size_t kPriorityIconRowBytes = (kPriorityIconSize + 7) / 8;  // 3

// Ikona priorytetu 1-bit 18x18 dla e-papieru, w formacie GxEPD2 drawBitmap: wiersze od góry,
// w każdym bajcie najstarszy bit = lewy piksel, 1 = czarny.
//   wysoki:   pełna flaga (drzewce + wypełniony płat)
//   normalny: flaga w obrysie (to samo drzewce, płat z obramowaniem 2 px)
//   niski:    pozioma kreska
struct PriorityIcon {
  int16_t width;
  int16_t height;
  const uint8_t* bits;  // height * kPriorityIconRowBytes bajtów
};

const PriorityIcon& priorityIcon(Priority p);

// Piksel (x, y) ikony; poza obszarem = false.
bool iconPixel(const PriorityIcon& icon, int16_t x, int16_t y);

}  // namespace todo
