#pragma once

#include <string>

#include <ArduinoJson.h>

#include "task.h"

namespace todo {

// Format przewodowy zadania (wspólny z iOS). Klucze w stałej kolejności:
// id, owner, title, prio, due, status, rem, created, updated, by, del.
// "due" i "rem" są pomijane, gdy równe 0. "status": "active" | "done". "prio": 0..2.
void toJson(const Task& t, JsonObject out);
bool fromJson(JsonObjectConst in, Task& out);  // false: brak pola wymaganego lub zła wartość

std::string encodeTask(const Task& t);
bool decodeTask(const std::string& json, Task& out);

}  // namespace todo
