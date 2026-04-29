# MediDispense - Smart Medicine Adherence System

MediDispense is an IoT + mobile solution for medicine reminders, schedule tracking, and adherence insights.
It combines an Arduino dispenser (BLE + RTC + servo) with a Flutter app that supports dose-level tracking, offline voice guidance, and an on-device LLM assistant.

## What Is Implemented

### 1. Flutter App Core
- Bluetooth BLE connect/disconnect with the dispenser.
- Time sync from phone to Arduino RTC.
- Add medicine with structured fields:
  - Medicine name
  - Dosage
  - Tablets per dose
  - Times per day
  - Number of days
  - Purpose/indication
  - Start date
  - Scheduled times
- Schedule view for today and other dates.
- Dose actions for today only: Taken and Missed.
- Future date views are read-only.

### 2. Data Model and Database (SQLite)
- Medicines table expanded with:
  - tablets_per_dose
  - times_per_day
  - total_days
  - purpose
  - start_date
- Dose records table added for per-dose tracking:
  - scheduled_date
  - scheduled_time
  - status (pending/taken/missed)
  - delay_minutes
  - taken_time
  - is_manual
- Adherence metrics table present and used.
- Migration supports older DB versions.

### 3. Dose Generation and Tracking
- For each medicine, schedules are saved first.
- Dose records are generated for the full duration (days x times/day).
- Home screen shows doses for selected date.
- Delay minutes are captured when a dose is marked taken late.
- Summary stats are available per medicine:
  - total
  - taken
  - missed
  - pending
  - delay

### 4. Automation and Voice Guidance
- Foreground automation service checks due doses periodically.
- Auto-mark missed after grace period for pending overdue doses.
- Voice guidance is generated and spoken via flutter_tts.
- Background alarm scheduling is integrated with android_alarm_manager_plus for due-dose triggers.

### 5. Dynamic Rule-Based Assistant (Model 2)
- Keyword-based medicine category detection (not strict string equality).
- Category examples include BP, Diabetes, Fever, Cough, Headache, Cholesterol, Asthma, Heart, Thyroid, Pain.
- Uses medicine name + purpose for matching.
- Adds risk-level and time-of-day personalization to messages.
- Safe fallback response when output is unclear.

### 6. On-Device LLM Assistant (RAG-AI Assistant)
- Assistant name: RAG-AI Assistant.
- Uses TinyLlama 1.1B Chat via on-device inference (llama.cpp plugin path).
- Fixed health questions in UI.
- Builds structured prompt from local DB context:
  - User profile
  - Medicine list
  - Taken/missed/pending
  - Delay minutes
  - Adherence percentage
  - Risk level
- Generates longer responses (not limited to 2-3 sentences).
- Optional TTS playback for generated response.
- Safe fallback text is shown if model output is not usable.

## Tech Stack

### Flutter
- provider
- sqflite
- path
- intl
- flutter_blue_plus
- flutter_tts
- android_alarm_manager_plus
- onenm_local_llm

### Arduino
- ArduinoBLE
- RTC
- Servo

### Optional Python Backend (Legacy/Experimental)
- FastAPI service remains in backend/ as an optional component.
- Current mobile AI path is offline and in-app.

## Project Structure
- lib/:
  - screens/: UI (Home, Add Medicine, AI, Profile)
  - services/: DB, automation, TTS, background scheduler, RAG-AI assistant
  - providers/: app state
  - models/: entities
- arduino_ble_code.ino: Arduino BLE + dispensing logic
- backend/: optional legacy AI API

## Setup

### Flutter App
1. Install Flutter SDK.
2. Run:
   - flutter pub get
3. Run on a physical Android device:
   - flutter run

### Arduino
1. Open arduino_ble_code.ino in Arduino IDE.
2. Install libraries: ArduinoBLE, RTC, Servo.
3. Upload to Arduino Uno R4 WiFi.

### Optional Backend
1. Create and activate Python virtual environment.
2. Install dependencies from backend/requirements.txt.
3. Start API:
   - uvicorn app:app --host 0.0.0.0 --port 8000

## Notes
- BLE operations should be tested on a real phone.
- On-device TinyLlama requires Android arm64 physical device support.
- First model initialization may require download; later runs are local from cache.
- This app provides general guidance only and not medical prescriptions.
