#pragma once

// --- Piny: ePaper Driver Board for XIAO <-> XIAO ESP32-S3 (BUSY zmierzony na D5) ---
#define EPD_RST   D0  // GPIO1
#define EPD_CS    D1  // GPIO2
#define EPD_BUSY  D5  // GPIO6
#define EPD_DC    D3  // GPIO4
#define EPD_SCK   D8  // GPIO7
#define EPD_MOSI  D10 // GPIO9

// Sprzętowa ramka panelu (rejestr 0x3C, sprawdzone na tym panelu):
// 0x00 = czarna (przejście wg LUT0), 0x01 = biała (domyślna w GxEPD2)
#define EPD_BORDER  0x00

// --- Czas: tylko do pokazania terminów zadań (urządzenie nie zna bieżącej godziny) ---
#define TZ_INFO    "CET-1CEST,M3.5.0,M10.5.0/3"

// --- BLE: usługa synchronizacji (te same UUID w aplikacji iOS, BLEDeviceLink.swift) ---
#define BLE_DEVICE_NAME       "Zadania"
#define BLE_SERVICE_UUID      "8b1f0001-6a4e-4d2b-9c7e-3f5a2b1c0d10"
#define BLE_REQUEST_UUID      "8b1f0002-6a4e-4d2b-9c7e-3f5a2b1c0d10"  // write: ramki żądania
#define BLE_RESPONSE_UUID     "8b1f0003-6a4e-4d2b-9c7e-3f5a2b1c0d10"  // indicate: ramki odpowiedzi
#define BLE_MTU               247
