#include <WiFi.h>
#include <FirebaseESP32.h>
#include <Keypad.h>
#include <LiquidCrystal_I2C.h>
#include <Preferences.h>
#include <ESP32Servo.h>
#include <MFRC522.h>
#include <time.h>

// Function declarations
void checkAndUpdateData();
void updateDoorStatus(bool status);
void resetPasswordInput();
void doorMode();
void connectToWiFi(const char* ssid, const char* password);
void printStoredData();
void checkDoorStatus();
void setWarning(bool status);

// RFID configuration
#define SS_PIN 5
#define RST_PIN 4
MFRC522 rfid(SS_PIN, RST_PIN);

// LCD configuration
LiquidCrystal_I2C lcd(0x27, 16, 2);

// Firebase configuration
FirebaseData fbData;
FirebaseAuth auth;
FirebaseConfig config;

// Servo configuration
Servo doorServo;
const int servoPin = 15;

// Keypad configuration
const byte ROWS = 4;
const byte COLS = 4;
char keys[ROWS][COLS] = {
  { '1', '2', '3', 'A' },
  { '4', '5', '6', 'B' },
  { '7', '8', '9', 'C' },
  { '*', '0', '#', 'D' }
};
byte pin_rows[ROWS] = { 13, 12, 14, 27 };
byte pin_columns[COLS] = { 26, 25, 33, 32 };
Keypad keypad = Keypad(makeKeymap(keys), pin_rows, pin_columns, ROWS, COLS);

// WiFi and storage variables
String wifiSSID = "BMTNLK 2.4G";
String wifiPassword = "10042022";
String firebasePassword = "";
String inputPassword = "";
bool isConnect = false;
bool doorStatus = false;

// Door state variables
bool isClose = true;
bool isOpen = false;

// Firebase update interval
unsigned long lastFirebaseCheck = 0;
const unsigned long firebaseCheckInterval = 5000;

// Door status check interval
unsigned long lastDoorStatusCheck = 0;
const unsigned long doorStatusCheckInterval = 1000;

// Warning and attempt tracking
int failedAttempts = 0;
bool warning = false;
unsigned long warningResetTime = 0;

// Preferences storage
Preferences preferences;
String cardUIDs[10];

void setup() {
  Serial.begin(115200);

  // Start LCD and Servo
  lcd.init();
  lcd.backlight();
  doorServo.attach(servoPin);
  doorServo.write(0);

  // Start RFID
  SPI.begin();
  rfid.PCD_Init();

  // Configure Firebase
  config.host = "smart-home-bc0ad-default-rtdb.firebaseio.com";
  config.signer.tokens.legacy_token = "TusGUO2NY63doZZnEjDOaMrWDjRArTpcmZaIiz9r";
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Connect to WiFi
  connectToWiFi(wifiSSID.c_str(), wifiPassword.c_str());

  // Retrieve stored data from Preferences
  preferences.begin("doorData", false);
  firebasePassword = preferences.getString("password", "");
  for (int i = 0; i < 10; i++) {
    cardUIDs[i] = preferences.getString(String(i).c_str(), "");
  }

  // Print stored data
  printStoredData();
}

void loop() {
  doorMode();

  if (millis() - lastFirebaseCheck >= firebaseCheckInterval) {
    checkAndUpdateData();
    lastFirebaseCheck = millis();
  }

  if (millis() - lastDoorStatusCheck >= doorStatusCheckInterval) {
    checkDoorStatus();
    lastDoorStatusCheck = millis();
  }

  if (warning && millis() >= warningResetTime) {
    setWarning(false);
    warningResetTime = 0;
  }
}

void printStoredData() {
  Serial.println("Stored data from Preferences:");
  Serial.println("Password: " + firebasePassword);

  Serial.print("UID list: ");
  for (int i = 0; i < 10; i++) {
    if (cardUIDs[i] != "") {
      Serial.print(cardUIDs[i] + " ");
    }
  }
  Serial.println();
  Serial.println("--------------------------------------------");
}

void doorMode() {
  if (doorStatus && isClose) {
    doorServo.write(90);
    isClose = false;
    isOpen = true;
    updateDoorStatus(true);
  }

  if (isClose) {
    lcd.setCursor(0, 0);
    lcd.print("Pass or Card!");

    char temp = keypad.getKey();
    if (temp) {
      if (temp != 'A' && temp != 'B' && temp != 'C' && temp != 'D' && temp != '*' && temp != '#') {
        inputPassword += temp;
        lcd.setCursor(inputPassword.length() - 1, 1);
        lcd.print('*');
      } else if (temp == '#') {
        if (inputPassword.length() > 0) {
          inputPassword.remove(inputPassword.length() - 1);
          lcd.clear();
          lcd.print("Pass or Card!");
          lcd.setCursor(0, 1);
          for (int i = 0; i < inputPassword.length(); i++) {
            lcd.print('*');
          }
        }
      } else if (temp == 'D') {
        if (inputPassword == firebasePassword) {
          lcd.clear();
          doorServo.write(90);
          isClose = false;
          isOpen = true;
          doorStatus = true;
          updateDoorStatus(true);
          failedAttempts = 0;
        } else {
          lcd.clear();
          lcd.print("Wrong Password!");
          delay(500);
          resetPasswordInput();
          failedAttempts++;

          if (failedAttempts > 3) {
            setWarning(true);
            warningResetTime = millis() + 5000;
          }
        }
      }
    }

    if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
      String readUID = "";
      for (byte i = 0; i < rfid.uid.size; i++) {
        if (rfid.uid.uidByte[i] < 0x10) {
          readUID += "0";
        }
        readUID += String(rfid.uid.uidByte[i], HEX);
      }
      rfid.PICC_HaltA();
      readUID.toUpperCase();

      bool isValidUID = false;
      for (int i = 0; i < 10; i++) {
        if (readUID.equalsIgnoreCase(cardUIDs[i])) {
          isValidUID = true;
          doorServo.write(90);
          isClose = false;
          isOpen = true;
          doorStatus = true;
          updateDoorStatus(true);
          failedAttempts = 0;
          break;
        }
      }

      if (!isValidUID) {
        lcd.clear();
        lcd.print("Wrong UID!");
        delay(500);
        resetPasswordInput();
        failedAttempts++;

        if (failedAttempts > 3) {
          setWarning(true);
          warningResetTime = millis() + 5000;
        }
      }
    }
  }

  if (isOpen) {
    lcd.setCursor(0, 0);
    lcd.print("Door Opened!");

    char temp = keypad.getKey();
    if (temp == 'C') {
      doorServo.write(0);
      isClose = true;
      isOpen = false;
      doorStatus = false;
      updateDoorStatus(false);
      resetPasswordInput();
    }
  }
}

void checkAndUpdateData() {
  if (isConnect) {
    bool updateRequired = false;

    if (Firebase.getString(fbData, "/door/password")) {
      String newPassword = fbData.stringData();
      if (newPassword != firebasePassword) {
        firebasePassword = newPassword;
        preferences.putString("password", firebasePassword);
        updateRequired = true;
      }
    }

    if (Firebase.getArray(fbData, "/door/cards")) {
      FirebaseJsonArray& uidArray = fbData.jsonArray();
      size_t len = uidArray.size();
      bool uidChanged = false;
      FirebaseJsonData jsonData;

      for (int i = 0; i < 10; i++) {
        String newUID = "";
        if (i < len && uidArray.get(jsonData, i) && jsonData.type == "string") {
          newUID = jsonData.stringValue.c_str();
        }
        if (newUID != cardUIDs[i]) {
          cardUIDs[i] = newUID;
          preferences.putString(String(i).c_str(), newUID);
          uidChanged = true;
        }
      }
      updateRequired = updateRequired || uidChanged;
    }

    if (updateRequired) {
      Serial.println("Data updated from Firebase.");
      printStoredData();
    }
  }
}

void checkDoorStatus() {
  String status = doorStatus ? "Open" : "Closed";
  Serial.println("Current door status: " + status);

  if (Firebase.getBool(fbData, "/door/status")) {
    bool newStatus = fbData.boolData();
    if (newStatus != doorStatus) {
      doorStatus = newStatus;
      if (doorStatus) {
        doorServo.write(90);
        isClose = false;
        isOpen = true;
      } else {
        doorServo.write(0);
        isClose = true;
        isOpen = false;
      }
    }
  }
}

void updateDoorStatus(bool status) {
  if (isConnect) {
    Firebase.setBool(fbData, "/door/status", status);
  }
}

void resetPasswordInput() {
  inputPassword = "";
  lcd.clear();
}

void connectToWiFi(const char* ssid, const char* password) {
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi ");
  Serial.println(ssid);
  int retryCount = 0;
  while (WiFi.status() != WL_CONNECTED && retryCount < 30) {
    delay(500);
    Serial.print(".");
    retryCount++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    isConnect = true;
    Serial.println("Connected!");
  } else {
    Serial.println("Failed to connect to WiFi.");
  }
}

void setWarning(bool status) {
  warning = status;
  if (isConnect) {
    Firebase.setBool(fbData, "/door/warning", status);
    if (status) {
      Serial.println("Warning: Too many failed attempts!");
    } else {
      Serial.println("Warning cleared.");
    }
  }
}