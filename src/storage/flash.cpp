#include "flash.h"

#include <FS.h>
#include <LittleFS.h>

static const char* STORE_PATH = "/store.bin";
static const char* MEMBERS_PATH = "/members.bin";

bool flashBegin() { return LittleFS.begin(true); }  // true: sformatuj przy pierwszym uruchomieniu

static bool readFile(const char* path, std::vector<uint8_t>& out) {
  File f = LittleFS.open(path, "r");
  if (!f) return false;
  out.resize(f.size());
  size_t n = f.read(out.data(), out.size());
  f.close();
  return n == out.size();
}

static bool writeFile(const char* path, const std::vector<uint8_t>& data) {
  String tmp = String(path) + ".tmp";
  File f = LittleFS.open(tmp, "w");
  if (!f) return false;
  size_t n = f.write(data.data(), data.size());
  f.close();
  if (n != data.size()) {
    LittleFS.remove(tmp);
    return false;
  }
  return LittleFS.rename(tmp, path);  // LittleFS podmienia istniejący plik atomowo
}

bool flashLoadStore(todo::TaskStore& out) {
  std::vector<uint8_t> data;
  if (!readFile(STORE_PATH, data)) return false;
  return todo::TaskStore::deserialize(data, out);
}

bool flashLoadMembers(todo::MemberRegistry& out) {
  std::vector<uint8_t> data;
  if (!readFile(MEMBERS_PATH, data)) return false;
  return todo::MemberRegistry::deserialize(data, out);
}

bool flashSaveStore(const todo::TaskStore& store) { return writeFile(STORE_PATH, store.serialize()); }

bool flashSaveMembers(const todo::MemberRegistry& members) { return writeFile(MEMBERS_PATH, members.serialize()); }
