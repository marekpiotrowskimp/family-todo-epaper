#include "store.h"

#include <algorithm>

#include "bytes.h"

namespace todo {

static const uint8_t kMagic[4] = {'T', 'D', 'S', '1'};

static bool valid(const Task& t) {
  if (t.id.empty() || t.ownerId.empty() || t.updatedBy.empty()) return false;
  if (t.updatedAt <= 0) return false;
  if (t.title.size() > kMaxTitleBytes) return false;
  if (t.title.empty() && !t.deleted) return false;
  return (uint8_t)t.priority <= (uint8_t)Priority::High && (uint8_t)t.status <= (uint8_t)Status::Done;
}

TaskStore::TaskStore(std::string storeId) : store_id_(std::move(storeId)) {}

UpsertResult TaskStore::upsert(const Task& t) {
  if (!valid(t)) return UpsertResult::RejectedInvalid;
  for (auto& st : tasks_) {
    if (st.task.id != t.id) continue;
    if (!wins(t, st.task)) return UpsertResult::Ignored;
    st.task = t;
    st.rev = ++revision_;
    return UpsertResult::Updated;
  }
  if (tasks_.size() >= kMaxTasks) {
    // Miejsce zwalnia najstarszy tombstone; aktywnych i ukończonych zadań nie usuwamy.
    auto oldest = tasks_.end();
    for (auto it = tasks_.begin(); it != tasks_.end(); ++it)
      if (it->task.deleted && (oldest == tasks_.end() || it->rev < oldest->rev)) oldest = it;
    if (oldest == tasks_.end()) return UpsertResult::RejectedFull;
    tasks_.erase(oldest);
  }
  tasks_.push_back(StoredTask{t, ++revision_});
  return UpsertResult::Inserted;
}

const Task* TaskStore::find(const std::string& id) const {
  for (auto& st : tasks_)
    if (st.task.id == id) return &st.task;
  return nullptr;
}

size_t TaskStore::size() const { return tasks_.size(); }

uint32_t TaskStore::revision() const { return revision_; }

const std::string& TaskStore::storeId() const { return store_id_; }

std::vector<Task> TaskStore::all() const {
  std::vector<Task> out;
  out.reserve(tasks_.size());
  for (auto& st : tasks_) out.push_back(st.task);
  return out;
}

std::vector<StoredTask> TaskStore::changesSince(uint32_t since, size_t limit) const {
  std::vector<StoredTask> out;
  for (auto& st : tasks_)
    if (st.rev > since) out.push_back(st);
  std::sort(out.begin(), out.end(), [](const StoredTask& a, const StoredTask& b) { return a.rev < b.rev; });
  if (out.size() > limit) out.resize(limit);
  return out;
}

std::vector<uint8_t> TaskStore::serialize() const {
  detail::Writer w;
  w.raw(kMagic, sizeof kMagic);
  w.str(store_id_);
  w.u32(revision_);
  w.u32((uint32_t)tasks_.size());
  for (auto& st : tasks_) {
    const Task& t = st.task;
    w.str(t.id);
    w.str(t.ownerId);
    w.str(t.title);
    w.u8((uint8_t)t.priority);
    w.i64(t.dueAt);
    w.u8((uint8_t)t.status);
    w.i64(t.reminderAt);
    w.i64(t.createdAt);
    w.i64(t.updatedAt);
    w.str(t.updatedBy);
    w.u8(t.deleted ? 1 : 0);
    w.u32(st.rev);
  }
  return w.finish();
}

bool TaskStore::deserialize(const std::vector<uint8_t>& data, TaskStore& out) {
  out = TaskStore();
  if (!detail::checkCrc(data, sizeof kMagic)) return false;
  detail::Reader r(data.data(), data.size() - 4);
  uint8_t magic[4];
  r.raw(magic, sizeof magic);
  if (!r.ok() || !std::equal(magic, magic + 4, kMagic)) return false;

  TaskStore s(r.str());
  s.revision_ = r.u32();
  uint32_t count = r.u32();
  if (!r.ok() || count > kMaxTasks) return false;
  for (uint32_t i = 0; i < count; i++) {
    Task t;
    t.id = r.str();
    t.ownerId = r.str();
    t.title = r.str();
    uint8_t prio = r.u8();
    t.dueAt = r.i64();
    uint8_t status = r.u8();
    t.reminderAt = r.i64();
    t.createdAt = r.i64();
    t.updatedAt = r.i64();
    t.updatedBy = r.str();
    t.deleted = r.u8() != 0;
    uint32_t rev = r.u32();
    if (!r.ok() || prio > (uint8_t)Priority::High || status > (uint8_t)Status::Done || rev > s.revision_) return false;
    t.priority = (Priority)prio;
    t.status = (Status)status;
    s.tasks_.push_back(StoredTask{t, rev});
  }
  if (!r.atEnd()) return false;
  out = std::move(s);
  return true;
}

}  // namespace todo
