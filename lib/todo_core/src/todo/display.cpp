#include "display.h"

#include <algorithm>
#include <string>

namespace todo {

bool displayBefore(const Task& a, const Task& b) {
  if (a.priority != b.priority) return a.priority > b.priority;
  bool aDue = a.dueAt != 0, bDue = b.dueAt != 0;
  if (aDue != bDue) return aDue;
  if (a.dueAt != b.dueAt) return a.dueAt < b.dueAt;
  if (a.createdAt != b.createdAt) return a.createdAt < b.createdAt;
  return a.id < b.id;
}

int listTop(size_t rowCount) {
  int n = (int)std::min(rowCount, kScreenRows);
  return (kScreenHeight - n * kRowHeight) / 2;
}

int rowTop(size_t index, size_t rowCount) { return listTop(rowCount) + (int)index * kRowHeight; }

bool rowReservesPageLabel(size_t index, size_t rowCount) {
  return rowTop(index, rowCount) + kRowHeight > kScreenHeight - kPageLabelHeight;
}

DisplayPage selectForDisplay(const std::vector<Task>& tasks, size_t rows, size_t page) {
  std::vector<Task> active;
  for (auto& t : tasks)
    if (!t.deleted && t.status == Status::Active) active.push_back(t);
  std::sort(active.begin(), active.end(), displayBefore);

  // Indeks najlepszego zadania każdej osoby; kolejność osób = kolejność ich najlepszych zadań.
  std::vector<size_t> tops;
  std::vector<std::string> owners;
  for (size_t i = 0; i < active.size(); i++) {
    if (std::find(owners.begin(), owners.end(), active[i].ownerId) != owners.end()) continue;
    owners.push_back(active[i].ownerId);
    tops.push_back(i);
  }

  DisplayPage out{{}, 0, 1};
  if (rows == 0 || tops.empty()) return out;

  if (tops.size() <= rows) {
    std::vector<bool> chosen(active.size(), false);
    for (size_t i : tops) chosen[i] = true;
    size_t free = rows - tops.size();
    for (size_t i = 0; i < active.size() && free > 0; i++) {
      if (chosen[i]) continue;
      chosen[i] = true;
      free--;
    }
    for (size_t i = 0; i < active.size(); i++)
      if (chosen[i]) out.items.push_back(active[i]);
    return out;
  }

  out.pageCount = (tops.size() + rows - 1) / rows;
  out.page = page % out.pageCount;
  size_t begin = out.page * rows;
  size_t end = std::min(begin + rows, tops.size());
  for (size_t k = begin; k < end; k++) out.items.push_back(active[tops[k]]);
  return out;
}

}  // namespace todo
