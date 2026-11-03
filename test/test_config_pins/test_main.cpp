// Charakteryzacja: mapowanie pinów e-paper zmierzone na sprzęcie (BUSY na D5, nie D2)
// i ramka panelu muszą przetrwać przebudowę firmware.
#include <unity.h>

#define D0 1000
#define D1 1001
#define D3 1003
#define D5 1005
#define D8 1008
#define D10 1010
#include "../../include/config.h"

void setUp() {}
void tearDown() {}

void test_epd_pins_match_driver_board() {
  TEST_ASSERT_EQUAL_INT(D0, EPD_RST);
  TEST_ASSERT_EQUAL_INT(D1, EPD_CS);
  TEST_ASSERT_EQUAL_INT(D5, EPD_BUSY);
  TEST_ASSERT_EQUAL_INT(D3, EPD_DC);
  TEST_ASSERT_EQUAL_INT(D8, EPD_SCK);
  TEST_ASSERT_EQUAL_INT(D10, EPD_MOSI);
}

void test_epd_border_is_black() { TEST_ASSERT_EQUAL_HEX8(0x00, EPD_BORDER); }

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_epd_pins_match_driver_board);
  RUN_TEST(test_epd_border_is_black);
  return UNITY_END();
}
