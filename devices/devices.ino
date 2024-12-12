#include <ESP8266WiFi.h>
#include <FirebaseESP8266.h>
#include <time.h>

// Wi-Fi Information
String wifiSSID = "BMTNLK 2.4G";
String wifiPassword = "10042022";

// Firebase Information
FirebaseConfig firebaseConfig;
FirebaseAuth firebaseAuth;

// Firebase Object
FirebaseData firebaseData;
unsigned long lastFirebaseCheck = 0;
const unsigned long firebaseCheckInterval = 500;

// Variables
bool isConnect = false;

// Light 1 (Pin D1)
bool l1Status = false;
bool l1Auto = false;
String light1OnTime = "";
String light1OffTime = "";
bool previousLight1Status = false;
int l1 = D1;

// Light 2 (Pin D2)
bool l2Status = false;
bool l2Auto = false;
String light2OnTime = "";
String light2OffTime = "";
bool previousLight2Status = false;
int l2 = D2;

// Water Heater (Pin D5)
bool whStatus = false;
bool whAuto = false;
String whOnTime = "";
String whOffTime = "";
bool previouswhStatus = false;
int wh = D5;

// Fan (Pin D6)
bool fanStatus = false;
int fan = D6;

// Gas Sensor (Analog Pin D7)
int gasSensor = D7;
int gasThreshold = 300;
bool gasWarning = false;

void setup() {
  Serial.begin(115200);

  connectToWiFi(wifiSSID.c_str(), wifiPassword.c_str());

  // Firebase Configurations
  firebaseConfig.database_url = "https://smart-home-bc0ad-default-rtdb.firebaseio.com";
  firebaseConfig.signer.tokens.legacy_token = "TusGUO2NY63doZZnEjDOaMrWDjRArTpcmZaIiz9r";

  // Initialize Firebase
  Firebase.begin(&firebaseConfig, &firebaseAuth);
  Firebase.reconnectWiFi(true);

  if (Firebase.ready()) {
    Serial.println("Connected to Firebase!");
  } else {
    Serial.println("Failed to connect to Firebase!");
  }

  configTime(7 * 3600, 0, "pool.ntp.org", "time.nist.gov");  // GMT+7 for Vietnam
  Serial.println("Syncing time with NTP...");

  while (!time(nullptr)) {
    Serial.print(".");
    delay(1000);
  }
  Serial.println("\nTime synced successfully!");

  pinMode(l1, OUTPUT);
  pinMode(l2, OUTPUT);
  pinMode(wh, OUTPUT);
  pinMode(fan, OUTPUT);
}

void loop() {
  updateFirebaseData();
    checkGasSensor();
}

void getDataFromFirebase() {
  if (Firebase.getBool(firebaseData, "/ligh1/status")) l1Status = firebaseData.boolData();
  if (Firebase.getBool(firebaseData, "/ligh1/auto")) l1Auto = firebaseData.boolData();
  if (l1Auto) {
    if (Firebase.getString(firebaseData, "/ligh1/ontime")) light1OnTime = firebaseData.stringData();
    if (Firebase.getString(firebaseData, "/ligh1/offtime")) light1OffTime = firebaseData.stringData();
  }

  if (Firebase.getBool(firebaseData, "/ligh2/status")) l2Status = firebaseData.boolData();
  if (Firebase.getBool(firebaseData, "/ligh2/auto")) l2Auto = firebaseData.boolData();
  if (l2Auto) {
    if (Firebase.getString(firebaseData, "/ligh2/ontime")) light2OnTime = firebaseData.stringData();
    if (Firebase.getString(firebaseData, "/ligh2/offtime")) light2OffTime = firebaseData.stringData();
  }

  if (Firebase.getBool(firebaseData, "/waterheater/status")) whStatus = firebaseData.boolData();
  if (Firebase.getBool(firebaseData, "/waterheater/auto")) whAuto = firebaseData.boolData();
  if (whAuto) {
    if (Firebase.getString(firebaseData, "/waterheater/ontime")) whOnTime = firebaseData.stringData();
    if (Firebase.getString(firebaseData, "/waterheater/offtime")) whOffTime = firebaseData.stringData();
  }

  if (Firebase.getBool(firebaseData, "/fan/status")) fanStatus = firebaseData.boolData();
}

void updateFirebaseData() {
  if (!isConnect) return;

  getDataFromFirebase();  
  Serial.println("Firebase Update:");

  updateDeviceStatus("Light 1", l1, l1Status, l1Auto, light1OnTime, light1OffTime, previousLight1Status, "/ligh1/status");
  updateDeviceStatus("Light 2", l2, l2Status, l2Auto, light2OnTime, light2OffTime, previousLight2Status, "/ligh2/status");
  updateDeviceStatus("Water Heater", wh, whStatus, whAuto, whOnTime, whOffTime, previouswhStatus, "/waterheater/status");

  Serial.print("Fan Status: ");
  Serial.println(fanStatus ? "ON" : "OFF");
  digitalWrite(fan, fanStatus ? HIGH : LOW);

  Serial.println("--------------------------------------------");
}

void updateDeviceStatus(String deviceName, int pin, bool& status, bool autoMode, String onTime, String offTime, bool& previousStatus, const String& firebasePath) {
  Serial.print(deviceName + " Status: ");
  Serial.println(status ? "ON" : "OFF");

  digitalWrite(pin, status ? HIGH : LOW);

  Serial.print(deviceName + " Auto Mode: ");
  Serial.println(autoMode ? "ON" : "OFF");

  if (autoMode) {
    Serial.println("Auto ON Time: " + onTime);
    Serial.println("Auto OFF Time: " + offTime);

    String currentTime = getRTC();
    if (currentTime == "") {
      Serial.println("Error: Cannot get time from RTC.");
      return;
    }

    if (currentTime == onTime && !previousStatus) {
      digitalWrite(pin, HIGH);
      updateFirebaseLightStatus(true, firebasePath);
      Serial.println(deviceName + " turned ON by schedule.");
      previousStatus = true;
    } else if (currentTime == offTime && previousStatus) {
      digitalWrite(pin, LOW);
      updateFirebaseLightStatus(false, firebasePath);
      Serial.println(deviceName + " turned OFF by schedule.");
      previousStatus = false;
    }
  }
}

String getRTC() {
  time_t now;
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Cannot get time from internal RTC!");
    return "";
  }
  char buffer[6];
  strftime(buffer, sizeof(buffer), "%H:%M", &timeinfo);
  return String(buffer);
}

void updateFirebaseLightStatus(bool status, const String& path) {
  if (Firebase.setBool(firebaseData, path, status)) {
    Serial.println("Updated status in Firebase for " + path);
  } else {
    Serial.println("Failed to update status in Firebase for " + path);
  }
}

void connectToWiFi(const char* ssid, const char* password) {
  WiFi.begin(ssid, password);
  int retries = 10;
  while (WiFi.status() != WL_CONNECTED && retries > 0) {
    delay(500);
    Serial.print(".");
    retries--;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("Connected successfully!");
    isConnect = true;
    delay(2000);
  } else {
    isConnect = false;
    Serial.println("Failed to connect!");
    delay(2000);
  }
}

void checkGasSensor() {
  int gasLevel = analogRead(gasSensor); // Đọc giá trị từ cảm biến khí gas
  Serial.print("Gas Level: ");
  Serial.println(gasLevel);

  // Kiểm tra mức khí gas
  if (gasLevel > gasThreshold) { // Nếu vượt ngưỡng
    if (!gasWarning) { // Chỉ cập nhật nếu trạng thái thay đổi
      gasWarning = true;
      if (Firebase.setBool(firebaseData, "/gas/status", true)) {
        Serial.println("Gas detected! Warning activated. Firebase updated.");
      } else {
        Serial.println("Failed to update Firebase for gas warning.");
      }
    }
  } else { // Nếu khí gas trở lại mức bình thường
    if (gasWarning) { // Chỉ cập nhật nếu trạng thái thay đổi
      gasWarning = false;
      if (Firebase.setBool(firebaseData, "/gas/status", false)) {
        Serial.println("Gas levels normal. Warning deactivated. Firebase updated.");
      } else {
        Serial.println("Failed to update Firebase for gas status normal.");
      }
    }
  }
}
