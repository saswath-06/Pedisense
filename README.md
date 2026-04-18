# Pedisense

**Smart insoles that map your foot pressure in real-time, detect biomechanical issues, and provide AI-powered rehabilitation guidance.**

Clinical pressure mats cost $15,000. We built a directionally accurate version for under $150 with an AI podiatrist powered by Gemini.

---

## The Problem

130,000 Americans lose a foot to diabetes every year because diabetic neuropathy destroys pressure sensation. Patients can't feel the sustained pressure that causes tissue breakdown and ulcers. Meanwhile, flat feet affect roughly 30% of adults, causing knee pain, hip misalignment, and plantar fasciitis. Most people don't know they have biomechanical problems until symptoms are severe. Clinical pressure analysis systems like RS Scan and Tekscan F-Scan cost $5,000 to $15,000, putting them out of reach for everyday monitoring.

## The Solution

Pedisense is a hardware + software system with three components:

**Instrumented insoles** with 10 FSR 402 sensors (5 per foot) and haptic vibration motors, wired through a CD74HC4067 analog multiplexer to an ESP32-WROOM-32 microcontroller. Data streams over BLE at 15Hz.

**iOS app** built in SwiftUI with real-time pressure heatmaps, diagnostic scanning, exercise biofeedback with live scoring, sustained pressure alerts with haptic feedback and notifications, longitudinal trend tracking, and AI-powered clinical reports.

**Gemini-powered AI agent** deployed on Railway that interprets raw sensor data, computes biomechanical metrics, generates plain-language clinical findings, builds personalized rehab plans, and produces shareable reports for podiatrists.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HARDWARE LAYER                               │
│                                                                     │
│  Left Insole (5 FSRs + Motor)  Right Insole (5 FSRs + Motor)       │
│  ┌─────────────────┐           ┌─────────────────┐                 │
│  │ S1: 1st Met      │           │ S6: 1st Met      │                │
│  │ S2: 5th Met      │           │ S7: 5th Met      │                │
│  │ S3: Med Midfoot  │           │ S8: Med Midfoot  │                │
│  │ S4: Med Heel     │           │ S9: Med Heel     │                │
│  │ S5: Lat Heel     │           │ S10: Lat Heel    │                │
│  │ M1: Haptic Motor │           │ M2: Haptic Motor │                │
│  └────────┬────────┘           └────────┬────────┘                 │
│           │ Voltage Dividers             │                          │
│           └──────────┬───────────────────┘                          │
│                      ▼                                              │
│           ┌────────────────────┐                                    │
│           │ CD74HC4067 16-Ch   │                                    │
│           │ Analog Multiplexer │                                    │
│           └────────┬───────────┘                                    │
│                    │ SIG → GPIO 36 (VP)                             │
│                    ▼                                                │
│              ┌──────────────┐                                       │
│              │ ESP32-WROOM  │                                       │
│              │ BLE + WiFi   │                                       │
│              └──────┬───────┘                                       │
│                     │ BLE Notify @ 15Hz (sensors)                   │
│                     │ BLE Write (motor control)                     │
└─────────────────────┼───────────────────────────────────────────────┘
                      │ ▲
┌─────────────────────┼─┼─────────────────────────────────────────────┐
│                     ▼ │          iOS APP (SwiftUI)                  │
│  BLEManager → CalibrationService → BiomechanicsAnalyzer            │
│                                  → AlertEngine → Motor Buzz        │
│                                  → AgentClient → Gemini API        │
│                                                                     │
│  Views: Heatmap │ Scan │ Exercise │ Alerts │ Trends │ Report        │
└─────────────────────┼───────────────────────────────────────────────┘
                      │ HTTPS
┌─────────────────────┼───────────────────────────────────────────────┐
│                     ▼         BACKEND (Railway)                     │
│  FastAPI + Gemini 2.5 Flash                                         │
│  Tools: analyze_pressure, generate_rehab_plan                       │
│  Endpoints: /analyze, /report, /health                              │
└─────────────────────────────────────────────────────────────────────┘
                      │
┌─────────────────────┼───────────────────────────────────────────────┐
│                     ▼         DATA (Supabase)                       │
│  Tables: calibrations, scans, reports, alerts                       │
│  Anonymous device-based identity                                    │
│  All scan data persists across sessions                              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Sensor Layout (5 per foot)

```
          LEFT FOOT                    RIGHT FOOT

        ┌─────────┐                  ┌─────────┐
        │         │                  │         │
        │  (S1)   │                  │   (S6)  │
        │ 1st Met │                  │ 1st Met │
        │         │                  │         │
        │      (S2)                  (S7)      │
        │     5th │                  │ 5th     │
        │     Met │                  │ Met     │
        │         │                  │         │
        │  (S3)   │                  │   (S8)  │
        │ Medial  │                  │ Medial  │
        │ Midfoot │                  │ Midfoot │
        │  +Motor │                  │ +Motor  │
        │         │                  │         │
        │ (S4)(S5)│                  │(S9)(S10)│
        │ Med Lat │                  │Med  Lat │
        │ Heel    │                  │Heel     │
        └─────────┘                  └─────────┘
```

S3/S8 (medial midfoot) is the key flat foot sensor. If this zone bears significant load, the arch is collapsed. The haptic motors sit next to S3/S8 in the arch area.

**Biomechanical metrics derived:**

- **Arch Index** = S3 / (S1+S2+S3+S4+S5). Healthy: 0.00-0.05. Flat foot: >0.12.
- **Pronation Index** = (S1+S3+S4) / (S2+S5). Healthy: 0.8-1.2. Overpronation: >1.3.
- **Heel Centering** = S4 / (S4+S5). Ideal: ~0.50. Eversion: >0.60. Inversion: <0.40.
- **Forefoot Balance** = S1 / (S1+S2). Ideal: 0.55-0.65.

---

## Hardware

### Parts List

| Part | Qty | Cost |
|------|-----|------|
| ESP32-WROOM-32 Dev Board | 1 | $10 |
| CD74HC4067 16-ch Analog Mux | 1 | $6 |
| FSR 402 (0-10kg round) | 10 | $80-120 |
| 10kΩ resistors | 10 | $3 |
| Coin vibration motors (3V) | 2 | $4 |
| 2N2222 NPN transistors | 2 | $2 |
| 1kΩ resistors (motor base) | 2 | $1 |
| Breadboard + jumper wires | - | $12 |
| Foam insoles or sandals | 1 pair | $8 |
| USB battery bank | 1 | $10 |

**Total: ~$140-170**

### Wiring

```
ESP32-WROOM-32 PIN ASSIGNMENTS
──────────────────────────────
VP (GPIO 36)  ← MUX SIG (analog read)
D4  (GPIO 4)  → MUX S0 (channel select)
D5  (GPIO 5)  → MUX S1
D18 (GPIO 18) → MUX S2
D19 (GPIO 19) → MUX S3
D25 (GPIO 25) → Left motor driver (via 1kΩ → 2N2222 base)
D26 (GPIO 26) → Right motor driver (via 1kΩ → 2N2222 base)
3V3           → MUX VCC, FSR rail, motor rail
GND           → MUX GND, MUX EN, resistors, motor emitters

FSR VOLTAGE DIVIDERS (x10)
──────────────────────────
3.3V → FSR → junction → 10kΩ → GND
Junction wire → MUX channel C0-C9

MOTOR DRIVER (x2)
─────────────────
3.3V → Motor+ → Motor- → 2N2222 Collector
GPIO → 1kΩ → 2N2222 Base
2N2222 Emitter → GND
```

---

## Software

### Repo Structure

```
Pedisense/
├── README.md
├── firmware/
│   └── pedisense.ino              # ESP32 Arduino firmware
├── agent/
│   ├── agent_server.py            # FastAPI + Gemini 2.5 Flash
│   ├── requirements.txt
│   └── Procfile                   # Railway deployment
├── ios/
│   └── Pedisense/
│       ├── PedisenseApp.swift
│       ├── ContentView.swift      # Tab routing + calibration gate
│       ├── BLEManager.swift       # CoreBluetooth + motor control
│       ├── CalibrationService.swift
│       ├── CalibrationView.swift
│       ├── HeatmapView.swift      # Real-time pressure heatmap
│       ├── HeatmapRenderer.swift  # IDW interpolation + foot paths
│       ├── ColorMap.swift         # Pressure-to-color mapping
│       ├── DiagnosticScanView.swift
│       ├── BiomechanicsAnalyzer.swift
│       ├── ExerciseView.swift     # Live biofeedback with scoring
│       ├── AlertEngine.swift      # Sustained pressure monitoring
│       ├── AlertView.swift
│       ├── TrendsView.swift       # Longitudinal charts (Swift Charts)
│       ├── ReportView.swift       # AI-generated clinical reports
│       ├── AgentClient.swift      # Railway API client
│       └── SupabaseManager.swift  # Data persistence
└── docs/
    └── photos/
```

### iOS App Features

**Live Heatmap** — Two foot-shaped heatmaps with inverse-distance-weighted interpolation from 5 sensor points per foot. Color scale from blue (no pressure) through green and yellow to red (high pressure). Real-time arch index and pronation index badges with alert flags.

**Calibration** — 5-second "stand evenly" baseline capture. All subsequent readings normalized as percentage of personal baseline, eliminating sensor-to-sensor manufacturing variation.

**Diagnostic Scan** — 10-second capture averaging ~150 frames. Computes all four biomechanical metrics per foot. Flags flat foot, overpronation, and heel imbalance. Automatically sends data to Gemini for AI-powered clinical interpretation and personalized exercise plan.

**Exercise Biofeedback** — Three exercise modes (Short Foot, Heel Centering, Forefoot Balance) with real-time scoring gauge. Score updates live as the user performs the exercise, with best-score tracking.

**Pressure Alerts** — Configurable threshold and duration. When a zone sustains pressure above the threshold for the set duration, fires a phone notification and buzzes the haptic motor on the affected foot. Runs in the background via CoreBluetooth background mode.

**Trends** — Longitudinal charts of arch index and pronation index across all saved scans, powered by real data from Supabase. Threshold lines show clinical boundaries.

**Clinical Report** — One-tap generation of a full clinical report via Gemini, structured as a formal podiatry document. Shareable via iOS share sheet.

### Agent Server

FastAPI backend deployed on Railway. Two endpoints:

`POST /analyze` — Accepts raw sensor readings, computes biomechanical metrics locally, generates rehab plan based on thresholds, sends everything to Gemini 2.5 Flash for clinical interpretation. Returns structured JSON with analysis text, metrics, and exercises.

`POST /report` — Accepts session data, generates a formal clinical podiatry report via Gemini.

`GET /health` — Health check.

### Data Persistence (Supabase)

Anonymous device-based identity using a UUID stored in UserDefaults. Four tables:

- **calibrations** — Baseline values per session
- **scans** — Raw readings, computed metrics, AI analysis text
- **reports** — Generated clinical reports
- **alerts** — Sustained pressure alert events with zone, foot, and duration

---

## How It Works

1. User puts on the insoles and opens the app
2. App connects to the ESP32 via BLE automatically
3. User calibrates by standing evenly for 5 seconds
4. Live heatmap shows real-time pressure distribution
5. User runs a diagnostic scan (10 seconds standing still)
6. Local biomechanics analysis runs instantly
7. Gemini AI provides clinical interpretation and exercise plan
8. User performs exercises with real-time biofeedback scoring
9. Alert system monitors for dangerous sustained pressure
10. All data saves to Supabase for longitudinal tracking
11. Clinical reports can be generated and shared with a podiatrist

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Microcontroller | ESP32-WROOM-32 (Arduino) |
| Sensors | FSR 402 x10, CD74HC4067 mux |
| Haptics | 3V coin motors, 2N2222 drivers |
| Communication | BLE (CoreBluetooth) |
| iOS App | SwiftUI, Swift Charts, CoreBluetooth |
| AI | Gemini 2.5 Flash (Google) |
| Backend | FastAPI, deployed on Railway |
| Database | Supabase (PostgreSQL) |
| Auth | Anonymous device UUID |

---

## Running Locally

### Firmware
1. Install Arduino IDE with ESP32 board package
2. Select "ESP32 Dev Module"
3. Flash `firmware/pedisense.ino`

### Agent Server
```bash
cd agent
pip install -r requirements.txt
export GEMINI_API_KEY="your-key"
uvicorn agent_server:app --host 0.0.0.0 --port 8000
```

### iOS App
1. Open `ios/Pedisense.xcodeproj` in Xcode
2. Add Supabase Swift package: `https://github.com/supabase-community/supabase-swift`
3. Select your iPhone as run destination
4. Cmd+R

---

## Demo

"130,000 Americans lose a foot to diabetes every year because they can't feel the pressure that causes ulcers. Clinical pressure mats cost $15,000. Pedisense costs $150, it vibrates to warn you, and it has an AI podiatrist built in."

The demo walks through: live heatmap responding to weight shifts, diagnostic scan detecting flat foot with AI analysis, exercise biofeedback with real-time scoring, sustained pressure alert triggering haptic motor buzz and phone notification, and a generated clinical report shareable with a podiatrist.

---

## Personal Note

I have flat feet. Both my parents are diabetic. This project exists because I wanted a way to monitor my own arch collapse and eventually protect my parents' feet from the pressure injuries they can't feel. Pedisense is that tool.

---

## Built At

HackPrinceton Spring 2026

## Team

Saswath Pall

## Prizes Targeted

- Best Hardware Hack
- Healthcare Track
- MLH Best Use of Gemini API
