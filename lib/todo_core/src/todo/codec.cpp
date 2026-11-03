#include "codec.h"

namespace todo {

void toJson(const Task& t, JsonObject out) {
  out["id"] = t.id;
  out["owner"] = t.ownerId;
  out["title"] = t.title;
  out["prio"] = (int)t.priority;
  if (t.dueAt != 0) out["due"] = t.dueAt;
  out["status"] = t.status == Status::Done ? "done" : "active";
  if (t.reminderAt != 0) out["rem"] = t.reminderAt;
  out["created"] = t.createdAt;
  out["updated"] = t.updatedAt;
  out["by"] = t.updatedBy;
  out["del"] = t.deleted;
}

static bool readString(JsonObjectConst in, const char* key, std::string& out) {
  if (!in[key].is<const char*>()) return false;
  out = in[key].as<const char*>();
  return true;
}

static bool readTime(JsonObjectConst in, const char* key, bool required, int64_t& out) {
  JsonVariantConst v = in[key];
  if (v.isNull()) {
    out = 0;
    return !required;
  }
  if (!v.is<int64_t>()) return false;
  out = v.as<int64_t>();
  return true;
}

bool fromJson(JsonObjectConst in, Task& out) {
  if (in.isNull()) return false;
  Task t;
  if (!readString(in, "id", t.id) || !readString(in, "owner", t.ownerId) || !readString(in, "title", t.title) ||
      !readString(in, "by", t.updatedBy))
    return false;
  if (!in["prio"].is<int>()) return false;
  int prio = in["prio"].as<int>();
  if (prio < (int)Priority::Low || prio > (int)Priority::High) return false;
  t.priority = (Priority)prio;
  std::string status;
  if (!readString(in, "status", status)) return false;
  if (status == "active") {
    t.status = Status::Active;
  } else if (status == "done") {
    t.status = Status::Done;
  } else {
    return false;
  }
  if (!readTime(in, "due", false, t.dueAt) || !readTime(in, "rem", false, t.reminderAt) ||
      !readTime(in, "created", true, t.createdAt) || !readTime(in, "updated", true, t.updatedAt))
    return false;
  if (!in["del"].is<bool>()) return false;
  t.deleted = in["del"].as<bool>();
  out = t;
  return true;
}

std::string encodeTask(const Task& t) {
  JsonDocument doc;
  toJson(t, doc.to<JsonObject>());
  std::string s;
  serializeJson(doc, s);
  return s;
}

bool decodeTask(const std::string& json, Task& out) {
  JsonDocument doc;
  if (deserializeJson(doc, json)) return false;
  return fromJson(doc.as<JsonObjectConst>(), out);
}

}  // namespace todo
