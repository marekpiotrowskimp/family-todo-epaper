// Ikony priorytetu na e-papier: dokładna geometria pikseli 18x18.
#include <functional>
#include <string>

#include <unity.h>

#include "todo/priority_icon.h"

using todo::Priority;
using todo::priorityIcon;

void setUp() {}
void tearDown() {}

static bool pole(int x, int y) { return (x == 3 || x == 4) && y >= 1 && y <= 16; }
static bool cloth(int x, int y) { return x >= 5 && x <= 15 && y >= 1 && y <= 9; }
static bool clothBorder(int x, int y) {
  return cloth(x, y) && (x <= 6 || x >= 14 || y <= 2 || y >= 8);  // obramowanie 2 px
}
static bool dash(int x, int y) { return x >= 3 && x <= 14 && (y == 8 || y == 9); }

static void assertShape(Priority p, const std::function<bool(int, int)>& expected, int expectedCount) {
  const auto& icon = priorityIcon(p);
  TEST_ASSERT_EQUAL_INT16(todo::kPriorityIconSize, icon.width);
  TEST_ASSERT_EQUAL_INT16(todo::kPriorityIconSize, icon.height);
  TEST_ASSERT_NOT_NULL(icon.bits);
  int count = 0;
  for (int y = 0; y < icon.height; y++) {
    for (int x = 0; x < icon.width; x++) {
      bool on = todo::iconPixel(icon, (int16_t)x, (int16_t)y);
      if (on) count++;
      if (on != expected(x, y)) {
        std::string msg = "piksel (" + std::to_string(x) + "," + std::to_string(y) + ")";
        TEST_FAIL_MESSAGE(msg.c_str());
      }
    }
  }
  TEST_ASSERT_EQUAL_INT(expectedCount, count);
}

void test_high_priority_is_filled_flag() {
  assertShape(Priority::High, [](int x, int y) { return pole(x, y) || cloth(x, y); }, 32 + 99);
}

void test_normal_priority_is_outlined_flag() {
  assertShape(Priority::Normal, [](int x, int y) { return pole(x, y) || clothBorder(x, y); }, 32 + 64);
}

void test_low_priority_is_dash() { assertShape(Priority::Low, dash, 24); }

void test_bitmap_uses_gxepd_row_format_msb_first() {
  // Wiersz 1 pełnej flagi: piksele 3..15 => bajty 0b00011111, 0b11111111, 0b00000000.
  const auto& icon = priorityIcon(Priority::High);
  TEST_ASSERT_NOT_NULL(icon.bits);
  const uint8_t* row1 = icon.bits + 1 * todo::kPriorityIconRowBytes;
  TEST_ASSERT_EQUAL_HEX8(0x1F, row1[0]);
  TEST_ASSERT_EQUAL_HEX8(0xFF, row1[1]);
  TEST_ASSERT_EQUAL_HEX8(0x00, row1[2]);
}

void test_pixels_outside_icon_are_off() {
  const auto& icon = priorityIcon(Priority::High);
  TEST_ASSERT_TRUE(todo::iconPixel(icon, 3, 1));  // kontrola: drzewce
  TEST_ASSERT_FALSE(todo::iconPixel(icon, -1, 1));
  TEST_ASSERT_FALSE(todo::iconPixel(icon, 18, 1));
  TEST_ASSERT_FALSE(todo::iconPixel(icon, 3, 18));
}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_high_priority_is_filled_flag);
  RUN_TEST(test_normal_priority_is_outlined_flag);
  RUN_TEST(test_low_priority_is_dash);
  RUN_TEST(test_bitmap_uses_gxepd_row_format_msb_first);
  RUN_TEST(test_pixels_outside_icon_are_off);
  return UNITY_END();
}
