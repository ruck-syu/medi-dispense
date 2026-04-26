# MediDispense - IoT-Based Medicine Dispenser

**MediDispense** is a complete hardware and software solution that automates medicine dispensing using an **Arduino Uno R4** and a companion **Flutter** mobile application. 

This project aims to assist elderly users or anyone who needs strict adherence to medication schedules by automating the physical dispensing process based on customized app schedules.

---

## 🌟 Key Features

### Mobile Application (Flutter)
- **Bluetooth BLE Integration:** Effortlessly scan and connect to the medicine dispenser using Bluetooth Low Energy.
- **Smart Time Synchronization:** Automatically synchronizes the Arduino's Real-Time Clock (RTC) with the smartphone's time immediately upon connection.
- **Schedule Management:** Add, edit, and track medication schedules. Select the specific medicine, dispensing time, and the physical compartment it resides in.
- **Smart Validation:** Automatically disables occupied compartments in the UI, ensuring two medicines aren't accidentally scheduled for the same slot at the same time.
- **Remote Hardware Control:** Send manual commands to reset the dispenser's servo motor to its default state directly from the app.
- **Patient Profile:** Manage basic patient details and store an organized list of predefined medicines (including dosage and cause).

### Hardware (Arduino)
- **Automated Dispensing:** Uses a Servo motor to rotate a 4-compartment dispenser at precise intervals.
- **Real-Time Tracking:** Relies on the Arduino's built-in RTC for 100% accurate dispensing, independent of a constant Bluetooth connection.
- **Visual & Audio Cues:** Triggers an LED and buzzer when a medication is dispensed to alert the user.

---

## 🛠 Tech Stack

- **Mobile Application:** 
  - Framework: [Flutter](https://flutter.dev/) (Dart)
  - State Management: `provider`
  - Local Database: `sqflite` (SQLite)
  - Bluetooth: `flutter_blue_plus`
- **Hardware:** 
  - Board: Arduino Uno R4 WiFi (leveraging built-in BLE & RTC)
  - Language: C++
  - Libraries: `ArduinoBLE.h`, `RTC.h`, `Servo.h`

---

## 🔌 Hardware Requirements

To build the physical dispenser, you will need:
1. **Arduino Uno R4 WiFi** (Requires built-in BLE and RTC)
2. **Servo Motor (180 degrees)**
3. **LED & 220-ohm Resistor** (For visual alerts)
4. **Buzzer** (For audio alerts)
5. **Push Button** (Optional manual trigger/reset)
6. A **3D-Printed or custom-built** 4-compartment medicine tray mounted to the servo.

---

## 🚀 Setup & Installation

### 1. Arduino Setup
1. Open `arduino_ble_code.ino` using the [Arduino IDE](https://www.arduino.cc/en/software).
2. Connect your Arduino Uno R4 WiFi via USB.
3. Ensure the following libraries are installed in the IDE:
   - `ArduinoBLE`
   - `RTC`
   - `Servo`
4. Compile and upload the sketch to the Arduino.
5. The Arduino will automatically begin broadcasting a BLE signal with the name **"MediDispense"**.

### 2. Flutter App Setup
1. Ensure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
2. Clone or open this repository.
3. Fetch the required dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app on a physical device (Bluetooth does not work on most emulators/simulators):
   ```bash
   flutter run
   ```
> **Note for iOS:** Ensure you have configured your Apple Developer account to sign the app, and that you have granted Bluetooth permissions when prompted.

### 3. Offline AI Setup (Risk + Voice)
The AI features now run fully inside Flutter with no backend, no API calls, and no `.pkl` files.

1. Risk prediction is recreated in Dart:
   - adherence `>= 80` -> `LOW`
   - adherence `50-79` -> `MEDIUM`
   - adherence `< 50` -> `HIGH`
2. Instruction generation is also implemented in Dart using the same medicine-specific rule set.
3. Voice output uses `flutter_tts` directly on the device.

### 4. Automatic AI Trigger Flow
- App polls active schedules every 20 seconds.
- When current time matches a schedule (`HH:MM`), it automatically:
  - reads local medicine and adherence values from SQLite,
  - calculates adherence,
  - predicts risk locally in Dart,
  - generates the instruction text,
  - speaks it using Flutter TTS.
- No button click is required.

Current language is English (`en`). The TTS layer is prepared for future multilingual support such as Hindi (`hi`) and Kannada (`kn`).

---

## 📡 Communication Protocol

The app and the Arduino communicate over Bluetooth Low Energy (BLE) using a custom Service UUID:
- **Service UUID:** `19b10000-e8f2-537e-4f6c-d104768a1214`

It utilizes two characteristics:
1. **Time Sync Characteristic (`19b10002...`)**
   - Expects a 14-character string: `YYYYMMDDHHMMSS`
   - Sets the Arduino RTC.
2. **Command Characteristic (`19b10001...`)**
   - `"RESET"`: Returns the servo to 0 degrees.
   - `"ADD:HH:MM:C"`: Adds a schedule at `HH:MM` for compartment `C`.
   - `"DEL:HH:MM:C"`: Removes a schedule at `HH:MM` for compartment `C`.

---

## 🛑 Constraints & Limitations
- **Compartments:** The current servo implementation is calibrated for a 180-degree motor and a 4-compartment tray ($45^{\circ}$ rotation per compartment).
- **Active Schedules:** The app restricts scheduling to a maximum of 4 active compartments simultaneously to match the physical hardware constraints.
- **Connection:** Time syncing only occurs when the app is actively opened and connected to the device. However, dispensing will continue to function accurately without a connection as long as the Arduino remains powered.