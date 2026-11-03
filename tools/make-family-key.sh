#!/bin/sh
# Generuje wspólny klucz rodziny i zapisuje go w dwóch plikach ignorowanych przez git:
#   include/family_key.h            (firmware ESP32)
#   ios/FamilyTodo/FamilyKey.swift  (aplikacja iOS)
# Oba pliki muszą mieć ten sam klucz. Istniejących plików nie nadpisuje bez --force.
set -eu
cd "$(dirname "$0")/.."

if [ "${1:-}" != "--force" ] && { [ -e include/family_key.h ] || [ -e ios/FamilyTodo/FamilyKey.swift ]; }; then
  echo "Klucz już istnieje. Użyj --force, żeby wygenerować nowy (trzeba wtedy wgrać firmware i zbudować aplikację)." >&2
  exit 1
fi

hex=$(openssl rand -hex 32)
bytes=$(echo "$hex" | sed 's/../0x&, /g; s/, $//')

cat > include/family_key.h <<H
// Wygenerowane przez tools/make-family-key.sh. Nie commituj.
#pragma once

#include <cstdint>

static const uint8_t FAMILY_KEY[32] = {$bytes};
H

cat > ios/FamilyTodo/FamilyKey.swift <<S
// Wygenerowane przez tools/make-family-key.sh. Nie commituj.
import Foundation

enum FamilyKey {
    static let secret = Data([$bytes])
}
S

echo "Zapisano include/family_key.h i ios/FamilyTodo/FamilyKey.swift."
