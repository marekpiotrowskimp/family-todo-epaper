#pragma once

#include "todo/auth.h"
#include "todo/store.h"

// Trwały zapis na LittleFS. Zapis przez plik tymczasowy i rename, więc zanik zasilania
// w trakcie zapisu zostawia poprzednią poprawną wersję.
bool flashBegin();
// false: brak pliku albo uszkodzone dane (wtedy `out` jest pusty).
bool flashLoadStore(todo::TaskStore& out);
bool flashLoadMembers(todo::MemberRegistry& out);
bool flashSaveStore(const todo::TaskStore& store);
bool flashSaveMembers(const todo::MemberRegistry& members);
