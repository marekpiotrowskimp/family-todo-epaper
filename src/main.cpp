// Rodzinna lista zadań na e-paper 4,2". Telefony synchronizują zadania przez BLE
// (lib/todo_core: protokół, scalanie LWW, wybór zadań na ekran); urządzenie nie używa Wi-Fi.

#include <Arduino.h>
#include <esp_random.h>

#include <algorithm>
#include <memory>

#include "ble/gatt.h"
#include "config.h"
#if __has_include("family_key.h")
#include "family_key.h"
#else
#error "Brak include/family_key.h: uruchom tools/make-family-key.sh (ten sam klucz trafi do aplikacji iOS)"
#endif
#include "storage/flash.h"
#include "todo/display.h"
#include "todo/refresh.h"
#include "todo/session.h"
#include "ui/screen.h"

static todo::TaskStore s_store;
static todo::MemberRegistry s_members;
static std::unique_ptr<todo::SyncSession> s_session;
static todo::RefreshScheduler s_refresh;
static std::vector<uint8_t> s_saved_members;
static size_t s_page_count = 1;

static void randomBytes(uint8_t* out, size_t len) { esp_fill_random(out, len); }

static std::string newStoreId() {
  uint8_t b[8];
  randomBytes(b, sizeof b);
  char buf[17];
  for (size_t i = 0; i < sizeof b; i++) snprintf(buf + 2 * i, 3, "%02x", b[i]);
  return buf;
}

// Każde połączenie zaczyna się od czystej sesji: autoryzacja nie przechodzi na kolejny telefon.
static void newSession() {
  todo::Secret key;
  std::copy(FAMILY_KEY, FAMILY_KEY + key.size(), key.begin());
  s_session.reset(new todo::SyncSession(s_store, s_members, key, randomBytes));
}

static void onDisplayDataChanged() {
  s_page_count = todo::selectForDisplay(s_store.all(), todo::kScreenRows, 0).pageCount;
  s_refresh.onDataChanged(millis());
}

static void handleRequest(const std::string& request) {
  gattSendResponse(s_session->handle(request));
  if (s_session->takeDataChanged()) {
    if (!flashSaveStore(s_store)) Serial.println("Błąd zapisu zadań na flash");
    onDisplayDataChanged();
  }
  std::vector<uint8_t> members = s_members.serialize();
  if (members != s_saved_members) {
    if (flashSaveMembers(s_members)) s_saved_members = members;
    else Serial.println("Błąd zapisu członków na flash");
    s_refresh.onDataChanged(millis());  // imiona przy zadaniach mogły się zmienić
  }
}

static void drawScreen() {
  todo::DisplayPage page = todo::selectForDisplay(s_store.all(), todo::kScreenRows, s_refresh.currentPage());
  ScreenState state;
  state.page = page.page;
  state.pageCount = page.pageCount;
  for (auto& t : page.items) {
    const todo::Member* m = s_members.find(t.ownerId);  // osoba usunięta z rejestru: sam tytuł
    state.rows.push_back({m ? m->displayName : "", t.title, t.priority, t.dueAt});
  }
  uint32_t start = millis();
  screenDraw(state);
  Serial.printf("Ekran: %u zadań, strona %u/%u, %lu ms\n", (unsigned)state.rows.size(), (unsigned)(page.page + 1),
                (unsigned)page.pageCount, millis() - start);
}

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("Start");
  setenv("TZ", TZ_INFO, 1);  // tylko do formatowania terminów
  tzset();

  screenBegin();
  if (!flashBegin()) Serial.println("Błąd LittleFS: dane nie przetrwają restartu");

  if (!flashLoadStore(s_store)) {
    // Brak lub uszkodzone dane: nowy storeId każe telefonom odtworzyć listę w całości.
    s_store = todo::TaskStore(newStoreId());
    flashSaveStore(s_store);
    Serial.printf("Nowa lista zadań, storeId %s\n", s_store.storeId().c_str());
  }
  if (!flashLoadMembers(s_members)) Serial.println("Brak zapamiętanych telefonów");
  s_saved_members = s_members.serialize();
  Serial.printf("Zadań: %u, rewizja %u, członków: %u\n", (unsigned)s_store.size(), (unsigned)s_store.revision(),
                (unsigned)s_members.size());

  s_page_count = todo::selectForDisplay(s_store.all(), todo::kScreenRows, 0).pageCount;
  newSession();
  gattBegin();
}

void loop() {
  if (gattTakeDisconnected()) newSession();

  if (gattTakeFrameError()) gattSendResponse(todo::SyncSession::frameErrorResponse());
  std::string request;
  if (gattTakeRequest(request)) handleRequest(request);

  if (s_refresh.due(millis(), s_page_count)) drawScreen();
  delay(10);
}
