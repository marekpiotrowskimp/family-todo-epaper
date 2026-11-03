#include "task.h"

namespace todo {

bool wins(const Task& incoming, const Task& current) {
  if (incoming.updatedAt != current.updatedAt) return incoming.updatedAt > current.updatedAt;
  return incoming.updatedBy.compare(current.updatedBy) > 0;  // char_traits: porównanie bajtów bez znaku
}

}  // namespace todo
