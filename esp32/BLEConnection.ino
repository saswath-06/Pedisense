#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
#define CHARACTERISTIC_UUID "abcdefab-1234-1234-1234-abcdefabcdef"
#define MOTOR_CHAR_UUID     "abcdefab-1234-1234-1234-abcdefab0002"

const int MUX_SIG = 36;
const int MUX_S0  = 4;
const int MUX_S1  = 5;
const int MUX_S2  = 18;
const int MUX_S3  = 19;

const int MOTOR_LEFT  = 25;
const int MOTOR_RIGHT = 26;

BLECharacteristic* pCharacteristic = nullptr;
BLECharacteristic* pMotorCharacteristic = nullptr;
bool deviceConnected = false;

class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("Client connected");
    }
    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        digitalWrite(MOTOR_LEFT, LOW);
        digitalWrite(MOTOR_RIGHT, LOW);
        Serial.println("Client disconnected");
        delay(500);
        pServer->getAdvertising()->start();
        Serial.println("Re-advertising...");
    }
};

class MotorCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pChar) {
        uint8_t* data = pChar->getData();
        size_t len = pChar->getLength();
        if (len < 2) return;

        uint8_t leftDur  = data[0];
        uint8_t rightDur = data[1];

        if (leftDur > 0) {
            digitalWrite(MOTOR_LEFT, HIGH);
            delay(leftDur * 10);
            digitalWrite(MOTOR_LEFT, LOW);
        }
        if (rightDur > 0) {
            digitalWrite(MOTOR_RIGHT, HIGH);
            delay(rightDur * 10);
            digitalWrite(MOTOR_RIGHT, LOW);
        }
    }
};

void selectMuxChannel(int channel) {
    digitalWrite(MUX_S0, channel & 0x01);
    digitalWrite(MUX_S1, (channel >> 1) & 0x01);
    digitalWrite(MUX_S2, (channel >> 2) & 0x01);
    digitalWrite(MUX_S3, (channel >> 3) & 0x01);
    delayMicroseconds(5);
}

void setup() {
    Serial.begin(115200);

    pinMode(MUX_S0, OUTPUT);
    pinMode(MUX_S1, OUTPUT);
    pinMode(MUX_S2, OUTPUT);
    pinMode(MUX_S3, OUTPUT);
    pinMode(MUX_SIG, INPUT);

    pinMode(MOTOR_LEFT, OUTPUT);
    pinMode(MOTOR_RIGHT, OUTPUT);
    digitalWrite(MOTOR_LEFT, LOW);
    digitalWrite(MOTOR_RIGHT, LOW);

    BLEDevice::init("Pedisense");
    BLEServer* pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    BLEService* pService = pServer->createService(SERVICE_UUID);

    pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pCharacteristic->addDescriptor(new BLE2902());

    pMotorCharacteristic = pService->createCharacteristic(
        MOTOR_CHAR_UUID,
        BLECharacteristic::PROPERTY_WRITE
    );
    pMotorCharacteristic->setCallbacks(new MotorCallbacks());

    pService->start();

    // THIS IS THE FIX - explicitly add UUID to advertisement
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();

    Serial.println("Pedisense BLE advertising started (with UUID in advert)");
}

void loop() {
    if (deviceConnected) {
        uint8_t data[20];

        const int CHANNEL_MAP[10] = {0, 1, 2, 4, 3, 5, 6, 7, 9, 8};

        for (int i = 0; i < 10; i++) {
            selectMuxChannel(CHANNEL_MAP[i]);
            uint16_t val = analogRead(MUX_SIG);
            data[i * 2]     = (val >> 8) & 0xFF;
            data[i * 2 + 1] = val & 0xFF;
        }

        pCharacteristic->setValue(data, 20);
        pCharacteristic->notify();

        delay(20);
    }
    delay(5);
}