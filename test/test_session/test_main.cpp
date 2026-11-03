#include <string>
#include <vector>

#include <ArduinoJson.h>
#include <unity.h>

#include "../helpers/fixtures.h"
#include "todo/codec.h"
#include "todo/session.h"
#include "../helpers/hex.h"

using todo::SyncSession;

// Kolejne wywołania generatora dają nonce a0..af, b0..bf, c0..cf, …
static uint8_t g_base;
static void fakeRandom(uint8_t* out, size_t len) {
  for (size_t i = 0; i < len; i++) out[i] = (uint8_t)(g_base + i);
  g_base += 0x10;
}

static todo::TaskStore* store;
static todo::MemberRegistry* members;
static SyncSession* session;

// MAC = HMAC(klucz rodziny 00..1f, nonce a0..af || "anna"); ten sam wektor co w iOS.
static const char* kAnnaMacForFirstNonce = "fac4725981f6273e72f559d39aaaf01973375f67fe07269384b8c32f2241fd4a";

static std::string authRequest(const std::string& user, const std::string& name, const std::string& mac) {
  JsonDocument doc;
  doc["op"] = "auth";
  doc["user"] = user;
  doc["name"] = name;
  doc["mac"] = mac;
  std::string s;
  serializeJson(doc, s);
  return s;
}

static std::string macFor(const std::string& user, uint8_t nonceBase) {
  todo::Nonce n{};
  for (size_t i = 0; i < n.size(); i++) n[i] = (uint8_t)(nonceBase + i);
  return toHex(todo::authMac(vectorSecret(), n, user));
}

void setUp() {
  g_base = 0xa0;
  store = new todo::TaskStore("S1");
  members = new todo::MemberRegistry();  // bez parowania: rejestr zaczyna pusty
  session = new SyncSession(*store, *members, vectorSecret(), fakeRandom);
}

void tearDown() {
  delete session;
  delete members;
  delete store;
}

static JsonDocument call(const std::string& req) {
  JsonDocument doc;
  deserializeJson(doc, session->handle(req));
  return doc;
}

static void assertError(const char* err, JsonDocument& res) {
  TEST_ASSERT_TRUE_MESSAGE(res["ok"].is<bool>(), "brak pola ok");
  TEST_ASSERT_FALSE(res["ok"].as<bool>());
  TEST_ASSERT_EQUAL_STRING(err, res["err"] | "");
}

static void login() {
  call("{\"op\":\"hello\"}");
  auto res = call(authRequest("anna", "Anna", kAnnaMacForFirstNonce));
  TEST_ASSERT_TRUE_MESSAGE(res["ok"] | false, "logowanie anny");
}

static std::string pushRequest(const std::vector<todo::Task>& ts) {
  JsonDocument doc;
  doc["op"] = "push";
  JsonArray arr = doc["tasks"].to<JsonArray>();
  for (auto& t : ts) todo::toJson(t, arr.add<JsonObject>());
  std::string s;
  serializeJson(doc, s);
  return s;
}

void test_hello_returns_nonce_store_id_and_revision() {
  auto res = call("{\"op\":\"hello\"}");
  TEST_ASSERT_TRUE(res["ok"] | false);
  TEST_ASSERT_EQUAL_STRING("a0a1a2a3a4a5a6a7a8a9aaabacadaeaf", res["nonce"] | "");
  TEST_ASSERT_EQUAL_STRING("S1", res["store"] | "");
  TEST_ASSERT_EQUAL_UINT32(0, res["rev"] | 99u);
}

void test_auth_with_family_key_registers_member_without_pairing() {
  call("{\"op\":\"hello\"}");
  auto res = call(authRequest("anna", "Anna", kAnnaMacForFirstNonce));
  TEST_ASSERT_TRUE(res["ok"] | false);
  TEST_ASSERT_TRUE(session->authenticated());
  TEST_ASSERT_NOT_NULL(members->find("anna"));
  TEST_ASSERT_EQUAL_STRING("Anna", members->find("anna")->displayName.c_str());
}

void test_returning_member_updates_display_name() {
  login();
  call("{\"op\":\"hello\"}");  // nonce b0..bf
  auto res = call(authRequest("anna", "Ania", macFor("anna", 0xb0)));
  TEST_ASSERT_TRUE(res["ok"] | false);
  TEST_ASSERT_EQUAL_UINT(1, members->size());
  TEST_ASSERT_EQUAL_STRING("Ania", members->find("anna")->displayName.c_str());
}

void test_new_member_is_accepted_when_registry_is_full() {
  for (size_t i = 0; i < todo::kMaxMembers; i++) {
    todo::Member m;
    m.userId = "u" + std::to_string(i);
    m.displayName = "U";
    members->add(m);
  }
  call("{\"op\":\"hello\"}");
  auto res = call(authRequest("anna", "Anna", kAnnaMacForFirstNonce));
  TEST_ASSERT_TRUE(res["ok"] | false);
  TEST_ASSERT_EQUAL_UINT(todo::kMaxMembers, members->size());
  TEST_ASSERT_NOT_NULL(members->find("anna"));
  TEST_ASSERT_NULL(members->find("u0"));  // najdawniej widziany
}

void test_auth_with_wrong_mac_fails_and_registers_nobody() {
  call("{\"op\":\"hello\"}");
  auto res = call(authRequest("anna", "Anna", std::string(64, '0')));
  assertError("bad_mac", res);
  TEST_ASSERT_FALSE(session->authenticated());
  TEST_ASSERT_EQUAL_UINT(0, members->size());
}

void test_auth_with_mac_for_other_user_fails() {
  call("{\"op\":\"hello\"}");
  auto res = call(authRequest("bartek", "Bartek", kAnnaMacForFirstNonce));
  assertError("bad_mac", res);
  TEST_ASSERT_NULL(members->find("bartek"));
}

void test_auth_without_hello_fails() {
  auto res = call(authRequest("anna", "Anna", kAnnaMacForFirstNonce));
  assertError("no_session", res);
  TEST_ASSERT_FALSE(session->authenticated());
}

void test_auth_requires_user_and_name_within_limit() {
  call("{\"op\":\"hello\"}");
  auto noName = call(authRequest("anna", "", kAnnaMacForFirstNonce));
  assertError("bad_request", noName);
  auto longName = call(authRequest("anna", repeatUtf8("ą", 16) + "a", kAnnaMacForFirstNonce));  // 33 B
  assertError("bad_request", longName);
  auto noUser = call(authRequest("", "Anna", kAnnaMacForFirstNonce));
  assertError("bad_request", noUser);
  TEST_ASSERT_EQUAL_UINT(0, members->size());

  auto maxName = call(authRequest("anna", repeatUtf8("ą", 16), kAnnaMacForFirstNonce));  // dokładnie 32 B
  TEST_ASSERT_TRUE(maxName["ok"] | false);
  TEST_ASSERT_EQUAL_STRING(repeatUtf8("ą", 16).c_str(), members->find("anna")->displayName.c_str());
}

void test_push_without_auth_is_rejected_and_store_untouched() {
  call("{\"op\":\"hello\"}");
  auto res = call(pushRequest({makeTask("t1", "anna")}));
  assertError("not_authenticated", res);
  TEST_ASSERT_EQUAL_UINT(0, store->size());
}

void test_new_hello_invalidates_previous_auth_and_old_mac() {
  login();
  call("{\"op\":\"hello\"}");  // nowy nonce b0..bf
  TEST_ASSERT_FALSE(session->authenticated());
  auto replay = call(authRequest("anna", "Anna", kAnnaMacForFirstNonce));
  assertError("bad_mac", replay);
  auto res = call(pushRequest({makeTask("t1", "anna")}));
  assertError("not_authenticated", res);
  TEST_ASSERT_EQUAL_UINT(0, store->size());
}

void test_push_after_auth_stores_tasks_and_reports_results() {
  login();
  TEST_ASSERT_FALSE(session->takeDataChanged());
  auto res = call(pushRequest({makeTask("t1", "anna"), makeTask("t2", "bartek")}));
  TEST_ASSERT_TRUE(res["ok"] | false);
  TEST_ASSERT_EQUAL_UINT(2, res["results"].size());
  TEST_ASSERT_EQUAL_STRING("inserted", res["results"][0] | "");
  TEST_ASSERT_EQUAL_STRING("inserted", res["results"][1] | "");
  TEST_ASSERT_EQUAL_UINT32(2, res["rev"] | 0u);
  TEST_ASSERT_EQUAL_UINT(2, store->size());
  TEST_ASSERT_TRUE(session->takeDataChanged());
  TEST_ASSERT_FALSE(session->takeDataChanged());
}

void test_repeated_push_after_interruption_is_idempotent() {
  login();
  auto batch = pushRequest({makeTask("t1", "anna"), makeTask("t2", "anna")});
  call(batch);
  session->takeDataChanged();
  auto res = call(batch);
  TEST_ASSERT_TRUE(res["ok"] | false);
  TEST_ASSERT_EQUAL_STRING("ignored", res["results"][0] | "");
  TEST_ASSERT_EQUAL_STRING("ignored", res["results"][1] | "");
  TEST_ASSERT_EQUAL_UINT32(2, res["rev"] | 0u);
  TEST_ASSERT_EQUAL_UINT(2, store->size());
  TEST_ASSERT_FALSE(session->takeDataChanged());
}

void test_invalid_task_in_batch_is_reported_per_task() {
  login();
  auto bad = makeTask("t2", "anna");
  bad.title = "";
  auto res = call(pushRequest({makeTask("t1", "anna"), bad}));
  TEST_ASSERT_TRUE(res["ok"] | false);
  TEST_ASSERT_EQUAL_STRING("inserted", res["results"][0] | "");
  TEST_ASSERT_EQUAL_STRING("rejected_invalid", res["results"][1] | "");
  TEST_ASSERT_EQUAL_UINT(1, store->size());
}

void test_undecodable_task_in_batch_is_rejected_invalid() {
  login();
  auto res = call(
      "{\"op\":\"push\",\"tasks\":[{\"id\":\"x\",\"prio\":9}," +
      todo::encodeTask(makeTask("t1", "anna")) + "]}");
  TEST_ASSERT_TRUE(res["ok"] | false);
  TEST_ASSERT_EQUAL_STRING("rejected_invalid", res["results"][0] | "");
  TEST_ASSERT_EQUAL_STRING("inserted", res["results"][1] | "");
}

void test_batch_larger_than_limit_is_rejected_whole() {
  login();
  std::vector<todo::Task> ts;
  for (size_t i = 0; i <= todo::kMaxBatch; i++) ts.push_back(makeTask("t" + std::to_string(i), "anna"));
  auto res = call(pushRequest(ts));
  assertError("batch_too_large", res);
  TEST_ASSERT_EQUAL_UINT(0, store->size());
}

void test_pull_pages_changes_since_cursor() {
  login();
  auto del = makeTask("t3", "anna");
  del.deleted = true;
  call(pushRequest({makeTask("t1", "anna"), makeTask("t2", "bartek"), del}));

  auto p1 = call("{\"op\":\"pull\",\"since\":0,\"limit\":2}");
  TEST_ASSERT_TRUE(p1["ok"] | false);
  TEST_ASSERT_EQUAL_STRING("S1", p1["store"] | "");
  TEST_ASSERT_EQUAL_UINT(2, p1["tasks"].size());
  TEST_ASSERT_EQUAL_STRING("t1", p1["tasks"][0]["id"] | "");
  TEST_ASSERT_EQUAL_STRING("t2", p1["tasks"][1]["id"] | "");
  TEST_ASSERT_EQUAL_UINT32(2, p1["rev"] | 0u);
  TEST_ASSERT_TRUE(p1["more"] | false);

  auto p2 = call("{\"op\":\"pull\",\"since\":2,\"limit\":2}");
  TEST_ASSERT_EQUAL_UINT(1, p2["tasks"].size());
  TEST_ASSERT_EQUAL_STRING("t3", p2["tasks"][0]["id"] | "");
  TEST_ASSERT_TRUE(p2["tasks"][0]["del"] | false);  // tombstone też trafia do telefonów
  TEST_ASSERT_EQUAL_UINT32(3, p2["rev"] | 0u);
  TEST_ASSERT_FALSE(p2["more"] | true);

  auto p3 = call("{\"op\":\"pull\",\"since\":3}");
  TEST_ASSERT_TRUE(p3["ok"] | false);
  TEST_ASSERT_EQUAL_UINT(0, p3["tasks"].size());
  TEST_ASSERT_EQUAL_UINT32(3, p3["rev"] | 0u);
  TEST_ASSERT_FALSE(p3["more"] | true);
}

void test_pull_limit_defaults_to_and_is_capped_at_max_batch() {
  login();
  for (int b = 0; b < 2; b++) {
    std::vector<todo::Task> ts;
    for (size_t i = 0; i < todo::kMaxBatch; i++) ts.push_back(makeTask("t" + std::to_string(b * 100 + i), "anna"));
    call(pushRequest(ts));
  }
  auto dflt = call("{\"op\":\"pull\",\"since\":0}");
  TEST_ASSERT_EQUAL_UINT(todo::kMaxBatch, dflt["tasks"].size());
  TEST_ASSERT_TRUE(dflt["more"] | false);
  auto capped = call("{\"op\":\"pull\",\"since\":0,\"limit\":500}");
  TEST_ASSERT_EQUAL_UINT(todo::kMaxBatch, capped["tasks"].size());
}

void test_pull_without_auth_is_rejected() {
  call("{\"op\":\"hello\"}");
  auto res = call("{\"op\":\"pull\",\"since\":0}");
  assertError("not_authenticated", res);
}

void test_hello_reports_current_revision() {
  login();
  call(pushRequest({makeTask("t1", "anna"), makeTask("t2", "anna")}));
  auto res = call("{\"op\":\"hello\"}");
  TEST_ASSERT_EQUAL_UINT32(2, res["rev"] | 0u);
  TEST_ASSERT_EQUAL_STRING("b0b1b2b3b4b5b6b7b8b9babbbcbdbebf", res["nonce"] | "");
}

void test_pair_operation_no_longer_exists() {
  auto res = call("{\"op\":\"pair\",\"user\":\"celina\",\"name\":\"Celina\","
                  "\"secret\":\"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f\"}");
  assertError("bad_request", res);
  TEST_ASSERT_NULL(members->find("celina"));
}

void test_frame_error_response_is_bad_frame() {
  JsonDocument res;
  TEST_ASSERT_FALSE(deserializeJson(res, SyncSession::frameErrorResponse()));
  assertError("bad_frame", res);
}

void test_malformed_or_unknown_requests_are_bad_request() {
  auto a = call("to nie json");
  assertError("bad_request", a);
  auto b = call("{\"op\":\"taniec\"}");
  assertError("bad_request", b);
  auto c = call("{\"nic\":1}");
  assertError("bad_request", c);
}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_hello_returns_nonce_store_id_and_revision);
  RUN_TEST(test_auth_with_family_key_registers_member_without_pairing);
  RUN_TEST(test_returning_member_updates_display_name);
  RUN_TEST(test_new_member_is_accepted_when_registry_is_full);
  RUN_TEST(test_auth_with_wrong_mac_fails_and_registers_nobody);
  RUN_TEST(test_auth_with_mac_for_other_user_fails);
  RUN_TEST(test_auth_without_hello_fails);
  RUN_TEST(test_auth_requires_user_and_name_within_limit);
  RUN_TEST(test_push_without_auth_is_rejected_and_store_untouched);
  RUN_TEST(test_new_hello_invalidates_previous_auth_and_old_mac);
  RUN_TEST(test_push_after_auth_stores_tasks_and_reports_results);
  RUN_TEST(test_repeated_push_after_interruption_is_idempotent);
  RUN_TEST(test_invalid_task_in_batch_is_reported_per_task);
  RUN_TEST(test_undecodable_task_in_batch_is_rejected_invalid);
  RUN_TEST(test_batch_larger_than_limit_is_rejected_whole);
  RUN_TEST(test_pull_pages_changes_since_cursor);
  RUN_TEST(test_pull_limit_defaults_to_and_is_capped_at_max_batch);
  RUN_TEST(test_pull_without_auth_is_rejected);
  RUN_TEST(test_hello_reports_current_revision);
  RUN_TEST(test_pair_operation_no_longer_exists);
  RUN_TEST(test_frame_error_response_is_bad_frame);
  RUN_TEST(test_malformed_or_unknown_requests_are_bad_request);
  return UNITY_END();
}
