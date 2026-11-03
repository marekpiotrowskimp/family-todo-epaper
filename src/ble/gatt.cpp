#include "gatt.h"

#include <Arduino.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>

#include "config.h"
#include "todo/frame.h"

static BLECharacteristic* s_response = nullptr;
// Mutex, nie spinlock: pod blokadą kopiujemy std::string (alokacja na stercie).
static SemaphoreHandle_t s_lock = nullptr;
static todo::Reassembler s_reassembler;  // używany tylko w zadaniu Bluetooth
static std::string s_request;
static bool s_has_request = false;
static bool s_disconnected = false;
static bool s_frame_error = false;
static volatile uint16_t s_mtu = 23;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server, esp_ble_gatts_cb_param_t* param) override {
    s_mtu = server->getPeerMTU(param->connect.conn_id);
    s_reassembler.reset();
  }
  void onDisconnect(BLEServer* server) override {
    xSemaphoreTake(s_lock, portMAX_DELAY);
    s_has_request = false;
    s_frame_error = false;
    s_disconnected = true;
    xSemaphoreGive(s_lock);
    s_reassembler.reset();
    BLEDevice::startAdvertising();  // jeden telefon naraz; kolejny może się połączyć po rozłączeniu
  }
  void onMtuChanged(BLEServer*, esp_ble_gatts_cb_param_t* param) override { s_mtu = param->mtu.mtu; }
};

class RequestCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    auto r = s_reassembler.feed(c->getData(), c->getLength());
    if (r == todo::Reassembler::Result::Error) {
      Serial.println("BLE: błędna ramka, wiadomość odrzucona");
      xSemaphoreTake(s_lock, portMAX_DELAY);
      s_frame_error = true;
      xSemaphoreGive(s_lock);
      return;
    }
    if (r != todo::Reassembler::Result::Complete) return;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    s_request = s_reassembler.message();
    s_has_request = true;
    xSemaphoreGive(s_lock);
  }
};

void gattBegin() {
  s_lock = xSemaphoreCreateMutex();
  BLEDevice::init(BLE_DEVICE_NAME);
  BLEDevice::setMTU(BLE_MTU);

  // Bez parowania i szyfrowania łącza (iOS nie pokazuje dialogu). Dostęp chroni protokół:
  // HMAC kluczem rodziny w auth.
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  BLEService* service = server->createService(BLE_SERVICE_UUID);

  BLECharacteristic* request = service->createCharacteristic(
      BLE_REQUEST_UUID, BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  request->setCallbacks(new RequestCallbacks());

  // Indications: telefon potwierdza każdą ramkę, więc przy dłuższej odpowiedzi nic nie ginie.
  s_response = service->createCharacteristic(BLE_RESPONSE_UUID, BLECharacteristic::PROPERTY_INDICATE);
  s_response->addDescriptor(new BLE2902());

  service->start();
  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(BLE_SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
}

bool gattTakeRequest(std::string& out) {
  bool has = false;
  xSemaphoreTake(s_lock, portMAX_DELAY);
  if (s_has_request) {
    out.swap(s_request);
    s_has_request = false;
    has = true;
  }
  xSemaphoreGive(s_lock);
  return has;
}

void gattSendResponse(const std::string& json) {
  // Indication mieści MTU - 3 bajty danych ATT; indicate() czeka na potwierdzenie telefonu.
  size_t frame = s_mtu > 3 ? s_mtu - 3 : 20;
  for (auto& f : todo::splitFrames(json, frame)) {
    s_response->setValue(f.data(), f.size());
    s_response->indicate();
  }
}

bool gattTakeDisconnected() {
  xSemaphoreTake(s_lock, portMAX_DELAY);
  bool d = s_disconnected;
  s_disconnected = false;
  xSemaphoreGive(s_lock);
  return d;
}

bool gattTakeFrameError() {
  xSemaphoreTake(s_lock, portMAX_DELAY);
  bool e = s_frame_error;
  s_frame_error = false;
  xSemaphoreGive(s_lock);
  return e;
}
