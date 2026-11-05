// Lista zadań rodziny na e-paperze 400x300 (README sekcja 5), bez nagłówka.
//
//   0 ┌──────────────────────────────────────┐
//     │ ⚑ Anna: Kupić mleko            31.10 │  do 9 wierszy po 33 px, wyśrodkowanych w pionie
//     │ ⚐ Bartek: Wynieść śmieci             │  ⚑ wysoki, ⚐ normalny, — niski (todo::priorityIcon)
//     │ …                                    │
//     │ Pranie                          1/2  │  numer strony w rogu tylko przy rotacji
// 300 └──────────────────────────────────────┘

#include "screen.h"

#include <Arduino.h>
#include <SPI.h>
#include <GxEPD2_BW.h>
#include <U8g2_for_Adafruit_GFX.h>
#include <time.h>

#include <algorithm>

#include "config.h"
#include "todo/display.h"
#include "todo/priority_icon.h"

// DEPG0420BNS19AF: 400x300, SSD1683. Tylko pełne odświeżanie (README sekcja 6).
// Nakładka ustawia sprzętową ramkę panelu (rejestr 0x3C) przed każdym odświeżeniem;
// GxEPD2 wpisuje tam na stałe 0x01 (biała ramka).
class Panel : public GxEPD2_420_GDEY042T81 {
 public:
  using GxEPD2_420_GDEY042T81::GxEPD2_420_GDEY042T81;
  using GxEPD2_420_GDEY042T81::refresh;
  void refresh(bool partial_update_mode = false) {
    _writeCommand(0x3C);  // Border Waveform Control
    _writeData(EPD_BORDER);
    GxEPD2_420_GDEY042T81::refresh(partial_update_mode);
  }
};
static GxEPD2_BW<Panel, Panel::HEIGHT> display(Panel(EPD_CS, EPD_DC, EPD_RST, EPD_BUSY));
static U8G2_FOR_ADAFRUIT_GFX u8g2;

static const int16_t W = 400, H = todo::kScreenHeight, MARGIN = 14;
static const int16_t ROW_H = todo::kRowHeight;
static const int16_t ICON_X = MARGIN, TEXT_X = MARGIN + todo::kPriorityIconSize + 6;

// Skraca tekst UTF-8 (po pełnych znakach), aż zmieści się w max_w razem z „…”.
static std::string fitText(const std::string& text, int16_t max_w) {
  if (u8g2.getUTF8Width(text.c_str()) <= max_w) return text;
  std::string s = text;
  while (!s.empty()) {
    do s.pop_back();
    while (!s.empty() && (static_cast<uint8_t>(s.back()) & 0xC0) == 0x80);
    std::string candidate = s + "…";
    if (u8g2.getUTF8Width(candidate.c_str()) <= max_w) return candidate;
  }
  return "…";
}

// Szerokość zarezerwowana w ostatnim wierszu na numer strony (0, gdy jest jedna strona).
static int16_t pageLabelWidth(const ScreenState& s, char* buf, size_t len) {
  if (s.pageCount <= 1) return 0;
  snprintf(buf, len, "%u/%u", (unsigned)(s.page + 1), (unsigned)s.pageCount);
  u8g2.setFont(u8g2_font_helvR10_te);
  return u8g2.getUTF8Width(buf) + 10;
}

static void drawRow(const ScreenRow& r, int16_t y, int16_t right) {
  const todo::PriorityIcon& icon = todo::priorityIcon(r.priority);
  display.drawBitmap(ICON_X, y + (ROW_H - icon.height) / 2, icon.bits, icon.width, icon.height, GxEPD_BLACK);

  if (r.dueAt != 0) {
    time_t t = (time_t)(r.dueAt / 1000);
    struct tm lt;
    localtime_r(&t, &lt);
    char buf[8];
    snprintf(buf, sizeof(buf), "%02d.%02d", lt.tm_mday, lt.tm_mon + 1);
    u8g2.setFont(u8g2_font_helvR12_te);
    int16_t w = u8g2.getUTF8Width(buf);
    u8g2.drawUTF8(right - w, y + 22, buf);
    right -= w + 10;
  }

  int16_t x = TEXT_X;
  if (!r.owner.empty()) {
    u8g2.setFont(u8g2_font_helvB12_te);
    std::string owner = r.owner + ": ";
    u8g2.drawUTF8(x, y + 22, owner.c_str());
    x += u8g2.getUTF8Width(owner.c_str());
  }
  u8g2.setFont(u8g2_font_helvR12_te);
  u8g2.drawUTF8(x, y + 22, fitText(r.title, right - x).c_str());
}

void screenBegin() {
  SPI.begin(EPD_SCK, -1, EPD_MOSI, EPD_CS);
  display.init(115200, true, 2, false);
  display.setRotation(0);  // poziomo, 400x300

  u8g2.begin(display);
  u8g2.setFontMode(1);
  u8g2.setForegroundColor(GxEPD_BLACK);
  u8g2.setBackgroundColor(GxEPD_WHITE);
}

void screenDraw(const ScreenState& s) {
  display.setFullWindow();
  display.firstPage();
  do {
    display.fillScreen(GxEPD_WHITE);
    char page[16] = "";
    int16_t pageW = pageLabelWidth(s, page, sizeof(page));
    size_t count = std::min(s.rows.size(), todo::kScreenRows);
    if (s.rows.empty()) {
      u8g2.setFont(u8g2_font_helvB14_te);
      const char* msg = "Brak zadań";
      u8g2.drawUTF8((W - u8g2.getUTF8Width(msg)) / 2, H / 2, msg);
    }
    for (size_t i = 0; i < count; i++) {
      bool reserve = todo::rowReservesPageLabel(i, count);
      drawRow(s.rows[i], (int16_t)todo::rowTop(i, count), W - MARGIN - (reserve ? pageW : 0));
    }
    if (pageW > 0) {
      u8g2.setFont(u8g2_font_helvR10_te);
      u8g2.drawUTF8(W - MARGIN - u8g2.getUTF8Width(page), H - 6, page);
    }
  } while (display.nextPage());
  display.hibernate();  // panel trzyma obraz bez zasilania; GxEPD2 budzi go resetem przy następnym rysowaniu
}
