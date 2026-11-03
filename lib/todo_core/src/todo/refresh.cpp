#include "refresh.h"

namespace todo {

void RefreshScheduler::onDataChanged(uint32_t nowMs) {
  dirty_ = true;
  changed_at_ = nowMs;
}

bool RefreshScheduler::due(uint32_t nowMs, size_t pageCount) {
  if (pageCount == 0) pageCount = 1;
  page_ %= pageCount;
  if (!started_) {
    started_ = true;
    dirty_ = false;
    last_refresh_ = nowMs;
    return true;
  }
  // Odejmowanie bez znaku działa także po przepełnieniu millis().
  if (dirty_ && (uint32_t)(nowMs - changed_at_) >= kSettleMs) {
    dirty_ = false;
    last_refresh_ = nowMs;
    return true;
  }
  if (pageCount > 1 && (uint32_t)(nowMs - last_refresh_) >= kRotateMs) {
    page_ = (page_ + 1) % pageCount;
    last_refresh_ = nowMs;
    return true;
  }
  return false;
}

size_t RefreshScheduler::currentPage() const { return page_; }

}  // namespace todo
