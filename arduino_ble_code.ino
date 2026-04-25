#include <Servo.h>
// LCD Code removed
#include <RTC.h>
#include <ArduinoBLE.h>

// Pin configuration
const int servoPin = 6;
const int buttonPin = 9;
const int ledPin = 7;
const int buzzerPin = 8;
const int rs = 12, en = 11, d4 = 5, d5 = 4, d6 = 3, d7 = 2;

// Servo variables
Servo servo;
int angle = 0;
int targetAngle = 0;
int stableAngle = 0;
int angleIncrement = 45;
unsigned long lastServoMoveTime = 0;
const int movementDelay = 50;

// Time variables
unsigned long lastTimeUpdate = 0;
unsigned long lastDispenseTime = 0;

// Max 10 schedules for simplicity
struct Schedule {
  int hour;
  int minute;
  int compartment;
  bool active;
};

Schedule schedules[10];

// LCD
LiquidCrystal lcd(rs, en, d4, d5, d6, d7);

// State variables
bool dispensing = false;

// BLE Service & Characteristics
BLEService dispenserService("19b10000-e8f2-537e-4f6c-d104768a1214"); 
// To receive commands like "RESET", "ADD:HH:MM:C", "DEL:HH:MM:C"
BLEStringCharacteristic commandChar("19b10001-e8f2-537e-4f6c-d104768a1214", BLERead | BLEWrite, 20);
// To sync time: "YYYYMMDDHHMMSS"
BLEStringCharacteristic timeSyncChar("19b10002-e8f2-537e-4f6c-d104768a1214", BLERead | BLEWrite, 15);

void setup() {
  Serial.begin(9600);

  pinMode(buttonPin, INPUT);
  pinMode(ledPin, OUTPUT);
  pinMode(buzzerPin, OUTPUT);
  digitalWrite(ledPin, LOW);
  noTone(buzzerPin);

  servo.attach(servoPin);
  servo.write(angle);

  RTC.begin();
  // Default start time, will be synced via BLE
  RTCTime startTime(28, Month::OCTOBER, 2025, 12, 00, 00, DayOfWeek::TUESDAY, SaveLight::SAVING_TIME_ACTIVE);
  RTC.setTime(startTime);

  // Initialize Schedules
  for(int i = 0; i < 10; i++) schedules[i].active = false;

  // Initialize BLE
  if (!BLE.begin()) {
    Serial.println("Starting BLE failed!");
    while (1);
  }

  BLE.setLocalName("MediDispense");
  BLE.setAdvertisedService(dispenserService);

  dispenserService.addCharacteristic(commandChar);
  dispenserService.addCharacteristic(timeSyncChar);
  BLE.addService(dispenserService);

  commandChar.writeValue("");
  timeSyncChar.writeValue("");

  BLE.advertise();
  Serial.println("BLE Peripheral Initialized");
}

void loop() {
  // BLE Handling
  BLEDevice central = BLE.central();
  if (central) {
    if (commandChar.written()) {
      String cmd = commandChar.value();
      handleCommand(cmd);
    }
    if (timeSyncChar.written()) {
      String tSync = timeSyncChar.value();
      handleTimeSync(tSync);
    }
  }

  // Update time display every second
  if (millis() - lastTimeUpdate >= 1000) {
    lastTimeUpdate = millis();
    if (!dispensing) {
      checkSchedules();
    }
  }

  // Handle non-blocking servo movement
  if (angle != targetAngle) {
    if (millis() - lastServoMoveTime > movementDelay) {
      lastServoMoveTime = millis();
      if (angle < targetAngle) {
        angle++;
        servo.write(angle);
      } else if (angle > targetAngle) {
        angle--;
        servo.write(angle);
      }
      if (angle == targetAngle) {
        stableAngle = angle;
      }
    }
  }

  // Handle dispensing state (display and alerts)
  if (dispensing) {
    if (millis() - lastDispenseTime > 5000) { 
      dispensing = false;
      noTone(buzzerPin);
      digitalWrite(ledPin, LOW);
    }
  }
}

void handleCommand(String cmd) {
  cmd.trim();
  if (cmd == "RESET") {
    targetAngle = 0;
  } else if (cmd.startsWith("ADD:")) {
    // Expected format: ADD:HH:MM:C
    int hr = cmd.substring(4, 6).toInt();
    int min = cmd.substring(7, 9).toInt();
    int comp = cmd.substring(10).toInt();
    
    // Find empty slot
    for(int i = 0; i < 10; i++) {
      if(!schedules[i].active) {
        schedules[i].hour = hr;
        schedules[i].minute = min;
        schedules[i].compartment = comp;
        schedules[i].active = true;
        break;
      }
    }
  } else if (cmd.startsWith("DEL:")) {
    // Expected format: DEL:HH:MM:C
    int hr = cmd.substring(4, 6).toInt();
    int min = cmd.substring(7, 9).toInt();
    int comp = cmd.substring(10).toInt();
    for(int i = 0; i < 10; i++) {
      if(schedules[i].active && schedules[i].hour == hr && schedules[i].minute == min && schedules[i].compartment == comp) {
        schedules[i].active = false;
      }
    }
  }
}

void handleTimeSync(String tSync) {
  // YYYYMMDDHHMMSS
  if (tSync.length() == 14) {
    int yr = tSync.substring(0, 4).toInt();
    int mo = tSync.substring(4, 6).toInt();
    int da = tSync.substring(6, 8).toInt();
    int hr = tSync.substring(8, 10).toInt();
    int mi = tSync.substring(10, 12).toInt();
    int se = tSync.substring(12, 14).toInt();

    RTCTime newTime(da, Month(mo), yr, hr, mi, se, DayOfWeek::MONDAY, SaveLight::SAVING_TIME_ACTIVE);
    RTC.setTime(newTime);
  }
}

void checkSchedules() {
  RTCTime currentTime;
  RTC.getTime(currentTime);
  
  // Only trigger at second 0
  if(currentTime.getSeconds() == 0) {
    for(int i = 0; i < 10; i++) {
      if(schedules[i].active && schedules[i].hour == currentTime.getHour() && schedules[i].minute == currentTime.getMinutes()) {
        // Trigger dispense
        lastDispenseTime = millis();
        dispensing = true;
        triggerDispense(schedules[i].compartment);
        break; // Max 1 per minute to avoid multi-triggers
      }
    }
  }
}

void triggerDispense(int compartment) {
  // Example simplistic movement for demonstration
  int newAngle = stableAngle + angleIncrement;
  if (newAngle > 180) {
    targetAngle = 0;
  } else {
    targetAngle = newAngle;
  }

  tone(buzzerPin, 1000);
  digitalWrite(ledPin, HIGH);
}
