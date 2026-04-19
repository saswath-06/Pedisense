# Pedisense

**Smart insoles that map your foot pressure in real-time, detect biomechanical issues, and provide AI-powered rehabilitation guidance.**

Clinical pressure mats cost $15,000. We built a directionally accurate version for under $80 with an AI podiatrist powered by Gemini.

---

## The Problem

130,000 Americans lose a foot to diabetes every year because diabetic neuropathy destroys pressure sensation. Patients can't feel the sustained pressure that causes tissue breakdown and ulcers. Meanwhile, flat feet affect roughly 30% of adults, causing knee pain, hip misalignment, and plantar fasciitis. Most people don't know they have biomechanical problems until symptoms are severe. Clinical pressure analysis systems like RS Scan and Tekscan F-Scan cost $5,000 to $15,000, putting them out of reach for everyday monitoring.

## The Solution

Pedisense is a hardware + software system with three components:

**Instrumented insoles** with 10 FSR 402 sensors (5 per foot) and haptic vibration motors, wired through a CD74HC4067 analog multiplexer to an ESP32-WROOM-32 microcontroller. Data streams over BLE at 15Hz.

**iOS app** built in SwiftUI with user authentication (Google Sign-In + email/password via Supabase Auth), real-time pressure heatmaps, diagnostic scanning, exercise biofeedback with live scoring, sustained pressure alerts with haptic feedback and push notifications, longitudinal trend tracking from real scan history, and AI-powered clinical reports.

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
│                                                                     │
│  Auth: Google Sign-In + Email/Password (Supabase Auth)             │
│  ↓                                                                  │
│  BLEManager → CalibrationService → BiomechanicsAnalyzer            │
│                                  → AlertEngine → Motor Buzz        │
│                                  → AgentClient → Gemini API        │
│                                  → SupabaseManager → Cloud Sync    │
│                                                                     │
│  Tabs: Heatmap │ Scan │ Exercise │ Alerts │ Trends │ Report │ Profile│
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
│  Auth: Google OAuth + Email/Password                                │
│  Tables: calibrations, scans, reports, alerts                       │
│  User-scoped data via authenticated user ID                         │
│  All data persists across sessions and devices                      │
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

S3/S8 (medial midfoot) is the key flat foot sensor. If this zone bears significant load, the arch is collapsed. The haptic motors sit next to S3/S8 in the arch area, where neuropathy patients are most likely to feel vibration feedback.

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
| FSR 402 (0-10kg round) | 10 | $30 |
| 10kΩ resistors | 10 | $3 |
| Coin vibration motors (3V) | 2 | $4 |
| 2N2222 NPN transistors | 2 | $2 |
| 1kΩ resistors (motor base) | 2 | $1 |
| Breadboard + jumper wires | - | $8 |
| Sandals (sensor mounting) | 1 pair | $3 |
| USB battery bank | 1 | $10 |

**Total: ~$77 CAD**

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
D27 (GPIO 27) → Right motor driver (via 1kΩ → 2N2222 base)
3V3           → MUX VCC, FSR rail, motor rail
GND           → MUX GND, MUX EN, resistors, motor emitters

MUX CHANNEL MAPPING
────────────────────
C0-C4: Left foot (1st met, 5th met, med midfoot, med heel, lat heel)
C5-C9: Right foot (same order)
```

---

## Software

### App Flow

1. **Authentication** — Sign in with Google or email/password via Supabase Auth. Session persists across launches.
2. **Calibration** — Stand evenly for 5 seconds to set personal baseline. Saved locally in UserDefaults and backed up to Supabase. Skipped on subsequent launches unless manually recalibrated.
3. **Main App** — Seven tabs plus recalibration in the More section.

### Tab Features

**Live Heatmap** — Two foot-shaped heatmaps with inverse-distance-weighted interpolation from 5 sensor points per foot. Normalized against calibration baseline. Real-time arch index and pronation index badges with alert flags. Haptic motor controls.

**Diagnostic Scan** — 10-second capture averaging ~150 frames. Computes all four biomechanical metrics per foot locally. Flags flat foot, overpronation, and heel imbalance. Automatically sends data to Gemini for AI-powered clinical interpretation and personalized exercise plan. Scan data saved to Supabase.

**Exercise Biofeedback** — Three exercise modes: Short Foot (arch activation), Heel Centering (balance), Forefoot Balance (weight distribution). Real-time scoring gauge with best-score tracking.

**Pressure Alerts** — Configurable ADC threshold and duration via sliders. Live zone timer circles. Push notification and haptic motor buzz when threshold is exceeded. Runs in background via CoreBluetooth background mode. Alert events saved to Supabase.

**Trends** — Longitudinal charts of arch index and pronation index from real Supabase scan data. Threshold lines show clinical boundaries.

**Clinical Report** — One-tap formal podiatry report via Gemini 2.5 Flash. Shareable via iOS share sheet. Saved to Supabase.

**Profile** — User email, calibration status, cloud sync status, AI agent status. Sign out clears session and calibration.

### Agent Server (Railway)

FastAPI backend with three endpoints:

- `POST /analyze` — Computes metrics, generates rehab plan, sends to Gemini for clinical interpretation
- `POST /report` — Generates formal podiatry report via Gemini
- `GET /health` — Health check

### Data Layer (Supabase)

Google OAuth + email/password authentication. Four PostgreSQL tables with row-level security:

- **calibrations** — Baseline values linked to authenticated user
- **scans** — Raw readings, computed metrics, AI analysis text
- **reports** — Generated clinical reports
- **alerts** — Sustained pressure alert events

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Microcontroller | ESP32-WROOM-32 (Arduino) |
| Sensors | FSR 402 x10, CD74HC4067 mux |
| Haptics | 3V coin motors, 2N2222 drivers |
| Communication | BLE (CoreBluetooth, background mode) |
| iOS App | SwiftUI, Swift Charts, CoreBluetooth |
| Authentication | Supabase Auth (Google OAuth + email) |
| AI | Gemini 2.5 Flash (Google) |
| Backend | FastAPI on Railway |
| Database | Supabase (PostgreSQL) |

---

## Running Locally

### Firmware
```bash
# Arduino IDE → Board: "ESP32 Dev Module" → Flash firmware/pedisense.ino
```

### Agent Server
```bash
cd agent
pip install -r requirements.txt
export GEMINI_API_KEY="your-key"
uvicorn agent_server:app --host 0.0.0.0 --port 8000
```

### iOS App
1. Open `ios/Pedisense.xcodeproj` in Xcode
2. Add packages: `supabase-swift`, `GoogleSignIn-iOS`
3. Configure Google OAuth Client ID in Info.plist
4. Run on physical iPhone (BLE requires real device)

---

## Personal Note

I have flat feet. Both my parents are diabetic. This project exists because I wanted a way to monitor my own arch collapse and eventually protect my parents' feet from the pressure injuries they can't feel. Pedisense is that tool.

---

## Built At

HackPrinceton Spring 2026

## Team

Saswath Yeshwanth & Harsukrit Pall