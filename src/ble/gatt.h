#pragma once

#include <string>

// Serwer GATT synchronizacji. Ramki odbierane są w zadaniu Bluetooth; złożone żądanie
// czeka, aż pętla główna odbierze je przez gattTakeRequest() i odeśle odpowiedź.
void gattBegin();
bool gattTakeRequest(std::string& out);
void gattSendResponse(const std::string& json);
// true raz po każdym rozłączeniu telefonu (sesję trzeba wtedy unieważnić).
bool gattTakeDisconnected();
// true raz po wiadomości, której ramek nie dało się złożyć (trzeba odpowiedzieć bad_frame).
bool gattTakeFrameError();
