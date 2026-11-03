#include "session.h"

#include <ArduinoJson.h>

#include "bytes.h"
#include "codec.h"

namespace todo {

namespace {

std::string reply(JsonDocument& doc) {
  std::string s;
  serializeJson(doc, s);
  return s;
}

std::string error(const char* code) {
  JsonDocument doc;
  doc["ok"] = false;
  doc["err"] = code;
  return reply(doc);
}

const char* resultName(UpsertResult r) {
  switch (r) {
    case UpsertResult::Inserted: return "inserted";
    case UpsertResult::Updated: return "updated";
    case UpsertResult::Ignored: return "ignored";
    case UpsertResult::RejectedFull: return "rejected_full";
    case UpsertResult::RejectedInvalid: break;
  }
  return "rejected_invalid";
}

// Porównanie w stałym czasie, żeby czas odpowiedzi nie zdradzał zgodnego prefiksu MAC.
bool sameDigest(const Digest& a, const Digest& b) {
  uint8_t diff = 0;
  for (size_t i = 0; i < a.size(); i++) diff |= a[i] ^ b[i];
  return diff == 0;
}

}  // namespace

SyncSession::SyncSession(TaskStore& store, MemberRegistry& members, const Secret& familyKey, RandomFn random)
    : store_(store), members_(members), family_key_(familyKey), random_(std::move(random)) {}

std::string SyncSession::frameErrorResponse() { return error("bad_frame"); }

std::string SyncSession::handle(const std::string& requestJson) {
  JsonDocument req;
  if (deserializeJson(req, requestJson) || !req.is<JsonObject>()) return error("bad_request");
  std::string op = req["op"] | "";

  if (op == "hello") {
    random_(nonce_.data(), nonce_.size());
    has_nonce_ = true;
    user_.clear();
    JsonDocument res;
    res["ok"] = true;
    res["nonce"] = detail::toHex(nonce_.data(), nonce_.size());
    res["store"] = store_.storeId();
    res["rev"] = store_.revision();
    return reply(res);
  }

  if (op == "auth") {
    if (!has_nonce_) return error("no_session");
    Member m;
    m.userId = req["user"] | "";
    m.displayName = req["name"] | "";
    if (m.userId.empty() || m.displayName.empty() || m.displayName.size() > kMaxNameBytes) return error("bad_request");
    Digest mac;
    if (!detail::fromHex(req["mac"] | "", mac.data(), mac.size())) return error("bad_mac");
    if (!sameDigest(mac, authMac(family_key_, nonce_, m.userId))) return error("bad_mac");
    user_ = m.userId;
    members_.add(m);
    JsonDocument res;
    res["ok"] = true;
    return reply(res);
  }

  if (op == "push") {
    if (!authenticated()) return error("not_authenticated");
    if (!req["tasks"].is<JsonArray>()) return error("bad_request");
    JsonArrayConst tasks = req["tasks"].as<JsonArrayConst>();
    if (tasks.size() > kMaxBatch) return error("batch_too_large");
    JsonDocument res;
    res["ok"] = true;
    JsonArray results = res["results"].to<JsonArray>();
    for (JsonVariantConst v : tasks) {
      Task t;
      UpsertResult r = fromJson(v.as<JsonObjectConst>(), t) ? store_.upsert(t) : UpsertResult::RejectedInvalid;
      if (r == UpsertResult::Inserted || r == UpsertResult::Updated) data_changed_ = true;
      results.add(resultName(r));
    }
    res["rev"] = store_.revision();
    return reply(res);
  }

  if (op == "pull") {
    if (!authenticated()) return error("not_authenticated");
    uint32_t since = req["since"] | 0u;
    size_t limit = req["limit"] | (unsigned)kMaxBatch;
    if (limit == 0 || limit > kMaxBatch) limit = kMaxBatch;
    auto changes = store_.changesSince(since, limit + 1);
    bool more = changes.size() > limit;
    if (more) changes.resize(limit);
    JsonDocument res;
    res["ok"] = true;
    res["store"] = store_.storeId();
    res["rev"] = more ? changes.back().rev : store_.revision();
    res["more"] = more;
    JsonArray arr = res["tasks"].to<JsonArray>();
    for (auto& st : changes) toJson(st.task, arr.add<JsonObject>());
    return reply(res);
  }

  return error("bad_request");
}

bool SyncSession::authenticated() const { return !user_.empty(); }

bool SyncSession::takeDataChanged() {
  bool changed = data_changed_;
  data_changed_ = false;
  return changed;
}

}  // namespace todo
