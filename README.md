# PressureMap

**Smart insoles that map your foot pressure in real-time, detect biomechanical issues, and provide AI-powered rehabilitation guidance.**

Clinical pressure mats cost $15,000. We built a directionally accurate version for ~$150, powered by an AI podiatrist agent.

---

## The Problem

- **130,000 Americans lose a foot to diabetes every year** because diabetic neuropathy destroys pressure sensation. Patients can't feel sustained pressure that causes tissue breakdown and ulcers.
- **Flat feet affect ~30% of adults**, causing cascading issues: knee pain, hip misalignment, plantar fasciitis. Most people don't know they have biomechanical problems until symptoms are severe.
- **Clinical pressure mats (RS Scan, Tekscan F-Scan) cost $5,000–$15,000.** We built a directionally accurate version for ~$150.
- **No existing consumer device gives real-time plantar pressure feedback** with haptic alerts and AI-driven analysis.

## The Solution

PressureMap is a hardware + software system:

1. **Instrumented insoles** — 10 FSR sensors (5 per foot) + 2 haptic vibration motors embedded in foam insoles, wired to an ESP32 microcontroller
2. **iOS app** — Real-time pressure heatmap, diagnostic scanning, exercise biofeedback, sustained pressure alerts with haptic feedback, gait replay, and trend tracking
3. **Dedalus-powered AI agent** — A biomechanical analysis agent built on the Dedalus Labs SDK that interprets your pressure data, generates plain-language findings, builds personalized rehab plans, and produces shareable reports for your podiatrist

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
│                    │ SIG (one ADC1 pin)                             │
│                    ▼                                                │
│              ┌──────────────┐                                       │
│              │ ESP32-WROOM  │                                       │
│              │ 1 ADC + 4 MUX│                                       │
│              │ + 2 Motor GPIO│                                       │
│              └──────┬───────┘                                       │
│                     │ BLE Notify @ 50Hz (sensors)                   │
│                     │ BLE Write (motor control)                     │
└─────────────────────┼───────────────────────────────────────────────┘
                      │ ▲
┌─────────────────────┼─┼─────────────────────────────────────────────┐
│                     ▼ │          iOS APP                            │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │ BLEManager (CoreBluetooth)                                │      │
│  │   → parses 20-byte BLE payload (10 x uint16)             │      │
│  │   → writes 2-byte motor commands (left buzz, right buzz)  │      │
│  └──────────────────┬───────────────────────────────────────┘      │
│                     │                                               │
│  ┌──────────────────▼───────────────────────────────────────┐      │
│  │                 DATA PIPELINE                             │      │
│  │  CalibrationService → BiomechanicsAnalyzer → AlertEngine  │      │
│  │  AlertEngine triggers motor buzz via BLE write on breach  │      │
│  └──────────────────┬───────────────────────────────────────┘      │
│                     │                                               │
│  ┌──────────────────▼───────────────────────────────────────┐      │
│  │                    VIEWS                                   │      │
│  │  HeatmapView │ DiagnosticScanView │ ExerciseView          │      │
│  │  GaitReplayView │ TrendsView │ ReportView                 │      │
│  └──────────────────┬───────────────────────────────────────┘      │
│                     │                                               │
└─────────────────────┼───────────────────────────────────────────────┘
                      │ HTTPS (pressure data + session context)
┌─────────────────────┼───────────────────────────────────────────────┐
│                     ▼         DEDALUS AGENT LAYER                   │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │ DedalusRunner (Python)                                    │      │
│  │  model: "anthropic/claude-sonnet-4-20250514"              │      │
│  │  mcp_servers: ["brave-search"]                            │      │
│  │  tools: [analyze_pressure, generate_rehab_plan,           │      │
│  │          generate_report, compare_to_baseline]            │      │
│  └──────────────────────────────────────────────────────────┘      │
│                                                                     │
│  Agent capabilities:                                                │
│  • Interprets raw pressure arrays into clinical findings            │
│  • Classifies foot type (normal arch, flat, high arch, mixed)       │
│  • Detects pronation/supination patterns                            │
│  • Generates personalized short-foot exercise plans                 │
│  • Produces PDF-ready reports in plain language                     │
│  • Searches medical literature via Brave Search MCP                 │
│  • Tracks longitudinal changes across sessions                     │
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
        │         │                  │         │
        │         │                  │         │
        │ (S4)(S5)│                  │(S9)(S10)│
        │ Med Lat │                  │Med  Lat │
        │ Heel    │                  │Heel     │
        └─────────┘                  └─────────┘
```

**Why 5 sensors per foot (not 7 or 8):**

The 5 zones retained are the ones that drive every core feature. The two toe sensors (big toe, small toe) were cut because toe-off data is partially captured by the 1st metatarsal sensor (toe curling drives force into the ball), and they add wiring complexity without meaningfully improving diagnostic accuracy for the conditions we care about (flat feet, pronation, diabetic pressure hotspots).

| Sensor | Zone | What It Tells You |
|--------|------|-------------------|
| S1/S6 | 1st Metatarsal (ball, medial) | Forefoot balance, toe-off force |
| S2/S7 | 5th Metatarsal (ball, lateral) | Forefoot balance, lateral loading |
| S3/S8 | Medial Midfoot | THE flat foot sensor. If this lights up, arch is collapsed. |
| S4/S9 | Medial Heel | Heel centering, eversion detection |
| S5/S10 | Lateral Heel | Heel centering, inversion detection |

**Key biomechanical metrics derived:**

- **Pronation Index** = (S1 + S3 + S4) / (S2 + S5). Values > 1.3 indicate overpronation.
- **Arch Index** = S3 / (S1 + S2 + S3 + S4 + S5). Healthy range 0.0–0.05. Flat foot: > 0.15.
- **Heel Centering** = S4 / (S4 + S5). Ideal ~0.5. Deviation indicates eversion/inversion.
- **Forefoot Balance** = S1 / (S1 + S2). Ideal ~0.55–0.65 (slightly medial-dominant).

---

## Parts List

| Part | Qty | Approx Cost | Source |
|------|-----|-------------|--------|
| ESP32-WROOM-32 Dev Board (built-in BLE + WiFi) | 1 | $10 | Amazon / AliExpress |
| CD74HC4067 16-channel analog multiplexer breakout | 1 | $5–8 | Amazon / Adafruit |
| FSR 402 (force-sensing resistor, 0–10kg round) | 10 | $8–12 each ($80–120 total) | Interlink Electronics / Adafruit / DigiKey |
| 10kΩ resistors (1/4W, for voltage dividers) | 10 | $3 (pack) | Amazon |
| Coin vibration motors (10mm, 3V) | 2 | $3–5 (pack of 5+) | Amazon / Adafruit |
| NPN transistors (2N2222 or S8050) | 2 | $2 (pack) | Amazon |
| 1N4001 diodes (flyback protection) | 2 | $2 (pack) | Amazon |
| 1kΩ resistors (transistor base) | 2 | included in resistor pack | — |
| Half-size breadboard | 1 | $5 | Amazon |
| Jumper wires (M-M and M-F, assorted) | 1 pack | $7 | Amazon |
| Foam insoles (trim-to-fit) | 1 pair | $8 | Walmart / Amazon |
| Kapton tape (sensor + motor mounting) | 1 roll | $5 | Amazon |
| USB cable (micro-USB or USB-C, check your board) | 1 | $5 | Amazon |
| Portable USB battery bank (demo power) | 1 | $10 (already own?) | Amazon |

**Total: ~$145–175** (or less if you have some parts)

**Note on FSR choice:** FSR 402 is the round variant rated 0–10kg (100N). This is a strong fit for this application. In static standing, each sensor sees roughly 7kg (distributed across 5 zones per foot for a 70kg person), which lands right in the middle of the sensor's range and gives you clean gradient readings for the heatmap and diagnostics. During heel strike in walking, load spikes to 15–20kg on 2–3 zones, which will push the top of the range and compress the gradient, but you still get usable differentiation for gait replay. Static features (diagnostic scan, exercise biofeedback, sustained pressure alerts) are the core demo and work perfectly within the 0–10kg range. Production version would use FlexiForce A401 (rated to 445N) for full dynamic range during running.

---

## Wiring Diagram

```
     FSR VOLTAGE DIVIDERS (x10)        CD74HC4067 MUX BREAKOUT
     ─────────────────────────         ─────────────────────────
                                       │                       │
     3.3V ── FSR S1 ──┬── 10kΩ ── GND │  C0  ◄── junction S1  │
     3.3V ── FSR S2 ──┬── 10kΩ ── GND │  C1  ◄── junction S2  │
     3.3V ── FSR S3 ──┬── 10kΩ ── GND │  C2  ◄── junction S3  │
     3.3V ── FSR S4 ──┬── 10kΩ ── GND │  C3  ◄── junction S4  │
     3.3V ── FSR S5 ──┬── 10kΩ ── GND │  C4  ◄── junction S5  │
     3.3V ── FSR S6 ──┬── 10kΩ ── GND │  C5  ◄── junction S6  │
     3.3V ── FSR S7 ──┬── 10kΩ ── GND │  C6  ◄── junction S7  │
     3.3V ── FSR S8 ──┬── 10kΩ ── GND │  C7  ◄── junction S8  │
     3.3V ── FSR S9 ──┬── 10kΩ ── GND │  C8  ◄── junction S9  │
     3.3V ── FSR S10──┬── 10kΩ ── GND │  C9  ◄── junction S10 │
                                       │  C10–C15  (unused)    │
                                       │                       │
                                       │  SIG ─────────────────┼──► GPIO 36 (ADC1_CH0)
                                       │  S0  ─────────────────┼──► GPIO 16
                                       │  S1  ─────────────────┼──► GPIO 17
                                       │  S2  ─────────────────┼──► GPIO 18
                                       │  S3  ─────────────────┼──► GPIO 19
                                       │  EN  ─────────────────┼──► GND (always enabled)
                                       │  VCC ─────────────────┼──► 3.3V
                                       │  GND ─────────────────┼──► GND
                                       └───────────────────────┘

     ESP32-WROOM-32 PIN SUMMARY
     ──────────────────────────
     GPIO 36 (input only) ◄── MUX SIG (analog reads)
     GPIO 16 ──► MUX S0 (channel select bit 0)
     GPIO 17 ──► MUX S1 (channel select bit 1)
     GPIO 18 ──► MUX S2 (channel select bit 2)
     GPIO 19 ──► MUX S3 (channel select bit 3)
     GPIO 25 ──► Left motor driver base (via 1kΩ)
     GPIO 26 ──► Right motor driver base (via 1kΩ)
     3.3V    ──► MUX VCC, FSR rail, motor rail
     GND     ──► MUX GND, MUX EN, resistor rail, motor emitters


     EACH MOTOR DRIVER CIRCUIT (x2):

                    3.3V
                     │
               ┌─────┤
               │  1N4001 (flyback diode,
               │  cathode to 3.3V,
               │  anode to motor-)
            Motor
               │
               └─────┬──── Collector (2N2222)
                     │
     GPIO ── 1kΩ ── Base (2N2222)
                     │
                  Emitter
                     │
                    GND
```

**Why a multiplexer:** The ESP32-WROOM-32's ADC2 is disabled when WiFi or BLE is active, leaving only 6 ADC1 pins. The CD74HC4067 routes all 10 FSR signals through a single ADC1 pin (GPIO 36), with 4 digital GPIOs selecting which channel to read. The ESP32 cycles through all 10 channels sequentially in the loop. At ~5μs settling time per channel, all 10 readings complete in under 100μs, well within the 20ms BLE notify interval.

**Motor driver explanation:** The ESP32 GPIO can't source enough current for a motor directly (~12mA limit vs ~80mA motor draw). The NPN transistor acts as a switch: GPIO goes HIGH, base current flows through the 1kΩ resistor, transistor saturates, motor spins. The 1N4001 flyback diode protects the transistor from the voltage spike when the motor turns off (back-EMF from the coil).

**ADC note:** ESP32-WROOM-32 uses 12-bit ADC (0–4095). GPIO 36 is an input-only pin on ADC1, safe to use with BLE active. The 10kΩ pull-down gives good sensitivity across the FSR 402's 0–10kg range. Note: the original ESP32's ADC has known nonlinearity at the extremes (below ~100mV and above ~3.1V). For this application it doesn't matter since we use relative pressure differences, not absolute force values.

---

## ESP32 Firmware (Arduino)

```cpp
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
#define CHARACTERISTIC_UUID "abcdefab-1234-1234-1234-abcdefabcdef"
#define MOTOR_CHAR_UUID     "abcdefab-1234-1234-1234-abcdefab0002"

// 10 FSR sensors read via CD74HC4067 mux
// Left foot: channels 0-4, Right foot: channels 5-9

// Mux pins
const int MUX_SIG = 36;  // ADC1_CH0, input only
const int MUX_S0  = 16;
const int MUX_S1  = 17;
const int MUX_S2  = 18;
const int MUX_S3  = 19;

// Motor pins
const int MOTOR_LEFT  = 25;
const int MOTOR_RIGHT = 26;

BLECharacteristic* pCharacteristic = nullptr;
BLECharacteristic* pMotorCharacteristic = nullptr;
bool deviceConnected = false;

class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) { deviceConnected = true; }
    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        // Kill motors on disconnect
        digitalWrite(MOTOR_LEFT, LOW);
        digitalWrite(MOTOR_RIGHT, LOW);
        pServer->getAdvertising()->start();
    }
};

// Motor command: 2 bytes [left_duration_ms_high, right_duration_ms_high]
// 0 = off, 1-255 = buzz duration in 10ms increments (10ms to 2550ms)
class MotorCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pChar) {
        uint8_t* data = pChar->getData();
        size_t len = pChar->getLength();
        if (len < 2) return;

        uint8_t leftDur  = data[0];  // 0 = off, N = buzz for N*10ms
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

void setup() {
    Serial.begin(115200);

    // Configure mux select pins
    pinMode(MUX_S0, OUTPUT);
    pinMode(MUX_S1, OUTPUT);
    pinMode(MUX_S2, OUTPUT);
    pinMode(MUX_S3, OUTPUT);
    pinMode(MUX_SIG, INPUT);

    // Configure motor pins
    pinMode(MOTOR_LEFT, OUTPUT);
    pinMode(MOTOR_RIGHT, OUTPUT);
    digitalWrite(MOTOR_LEFT, LOW);
    digitalWrite(MOTOR_RIGHT, LOW);

    // BLE setup
    BLEDevice::init("PressureMap");
    BLEServer* pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    BLEService* pService = pServer->createService(SERVICE_UUID);

    // Sensor data characteristic (notify)
    pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pCharacteristic->addDescriptor(new BLE2902());

    // Motor control characteristic (write)
    pMotorCharacteristic = pService->createCharacteristic(
        MOTOR_CHAR_UUID,
        BLECharacteristic::PROPERTY_WRITE
    );
    pMotorCharacteristic->setCallbacks(new MotorCallbacks());

    pService->start();
    pServer->getAdvertising()->start();
    Serial.println("PressureMap BLE advertising started");
}

void selectMuxChannel(int channel) {
    digitalWrite(MUX_S0, channel & 0x01);
    digitalWrite(MUX_S1, (channel >> 1) & 0x01);
    digitalWrite(MUX_S2, (channel >> 2) & 0x01);
    digitalWrite(MUX_S3, (channel >> 3) & 0x01);
    delayMicroseconds(5); // settling time
}

void loop() {
    if (deviceConnected) {
        // Read all 10 sensors via mux
        uint8_t data[20]; // 10 sensors x 2 bytes each (12-bit ADC values)

        for (int i = 0; i < 10; i++) {
            selectMuxChannel(i);
            uint16_t val = analogRead(MUX_SIG);
            data[i * 2]     = (val >> 8) & 0xFF;  // high byte
            data[i * 2 + 1] = val & 0xFF;          // low byte
        }

        pCharacteristic->setValue(data, 20);
        pCharacteristic->notify();

        delay(20); // ~50Hz update rate
    }
    delay(5);
}
```

---

## Dedalus Agent Backend

The AI layer runs as a lightweight FastAPI server wrapping the Dedalus SDK. The iOS app sends pressure data snapshots via HTTPS. The agent interprets the data and returns structured analysis.

### Setup

```bash
# Install dependencies
pip install dedalus-labs fastapi uvicorn python-dotenv

# Set API keys
export DEDALUS_API_KEY="your-dedalus-api-key"
```

### Agent Server (`agent_server.py`)

```python
import asyncio
import json
from fastapi import FastAPI, Request
from dedalus_labs import AsyncDedalus, DedalusRunner
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()

client = AsyncDedalus()
runner = DedalusRunner(client)

# --- Local Tools ---

def analyze_pressure(
    left_readings: list[int],
    right_readings: list[int],
    zones: list[str] = ["1st_met", "5th_met", "med_midfoot", "med_heel", "lat_heel"]
) -> str:
    """Analyze raw pressure readings from 10 FSR sensors (5 per foot).
    Returns computed biomechanical metrics: pronation index, arch index,
    heel centering, and forefoot balance for each foot."""

    def compute_metrics(readings, side):
        total = sum(readings) or 1
        s1, s2, s3, s4, s5 = readings

        pronation_idx = (s1 + s3 + s4) / max(s2 + s5, 1)
        arch_idx = s3 / total
        heel_center = s4 / max(s4 + s5, 1)
        forefoot_bal = s1 / max(s1 + s2, 1)

        return {
            "side": side,
            "raw": dict(zip(zones, readings)),
            "pronation_index": round(pronation_idx, 3),
            "arch_index": round(arch_idx, 3),
            "heel_centering": round(heel_center, 3),
            "forefoot_balance": round(forefoot_bal, 3),
            "total_load": total
        }

    left = compute_metrics(left_readings, "left")
    right = compute_metrics(right_readings, "right")
    return json.dumps({"left": left, "right": right}, indent=2)


def generate_rehab_plan(
    arch_index_left: float,
    arch_index_right: float,
    pronation_index_left: float,
    pronation_index_right: float
) -> str:
    """Generate a personalized rehabilitation exercise plan based on
    the user's biomechanical metrics. Returns structured exercise list."""

    exercises = []

    # Flat foot detected
    if arch_index_left > 0.12 or arch_index_right > 0.12:
        exercises.append({
            "name": "Short Foot Exercise",
            "description": "Sit with feet flat. Without curling toes, try to shorten your foot by pulling the ball toward the heel. Hold 5 seconds.",
            "sets": 3, "reps": 10, "frequency": "2x daily",
            "target_zone": "medial midfoot",
            "biofeedback_cue": "Watch medial midfoot sensor value decrease as arch activates"
        })
        exercises.append({
            "name": "Towel Scrunches",
            "description": "Place towel on floor, scrunch toward you using only toes. Full extension between reps.",
            "sets": 3, "reps": 15, "frequency": "daily",
            "target_zone": "1st metatarsal"
        })

    # Overpronation
    if pronation_index_left > 1.3 or pronation_index_right > 1.3:
        exercises.append({
            "name": "Single-Leg Balance (Lateral Focus)",
            "description": "Stand on one foot. Focus on keeping weight centered or slightly lateral. Use the heel centering metric as biofeedback.",
            "sets": 3, "reps": "30 sec holds", "frequency": "daily",
            "target_zone": "lateral heel",
            "biofeedback_cue": "Heel centering should trend toward 0.5"
        })

    if not exercises:
        exercises.append({
            "name": "Maintenance: Calf Raises",
            "description": "Your biomechanics look healthy. Maintain with bilateral calf raises for ankle stability.",
            "sets": 3, "reps": 15, "frequency": "3x weekly"
        })

    return json.dumps(exercises, indent=2)


def compare_to_baseline(
    current_arch_index: float,
    baseline_arch_index: float,
    current_pronation: float,
    baseline_pronation: float
) -> str:
    """Compare current session metrics to a stored baseline.
    Returns change analysis with direction and magnitude."""

    arch_change = current_arch_index - baseline_arch_index
    pron_change = current_pronation - baseline_pronation

    return json.dumps({
        "arch_index_change": round(arch_change, 4),
        "arch_direction": "improving" if arch_change < 0 else "worsening" if arch_change > 0 else "stable",
        "pronation_change": round(pron_change, 4),
        "pronation_direction": "improving" if pron_change < 0 else "worsening" if pron_change > 0 else "stable"
    }, indent=2)


# --- API Endpoints ---

@app.post("/analyze")
async def analyze(request: Request):
    body = await request.json()

    left = body["left_readings"]   # [s1, s2, s3, s4, s5]
    right = body["right_readings"] # [s6, s7, s8, s9, s10]

    prompt = f"""You are a biomechanical analysis agent for PressureMap, a smart insole system.

The user just completed a diagnostic scan. Analyze their pressure data using the analyze_pressure tool,
then interpret the results clinically. If arch_index > 0.12, flag flat foot. If pronation_index > 1.3,
flag overpronation. Generate a rehab plan using generate_rehab_plan.

Be specific, use the actual numbers, and write in plain language a patient can understand.
Structure your response as:
1. Summary (2 sentences)
2. Findings (specific metrics with clinical interpretation)
3. Recommended exercises (from the rehab plan tool)
4. What to show your podiatrist

Left foot raw ADC readings (1st met, 5th met, med midfoot, med heel, lat heel): {left}
Right foot raw ADC readings (1st met, 5th met, med midfoot, med heel, lat heel): {right}
"""

    response = await runner.run(
        input=prompt,
        model="anthropic/claude-sonnet-4-20250514",
        mcp_servers=["brave-search"],  # for medical literature lookups
        tools=[analyze_pressure, generate_rehab_plan, compare_to_baseline],
    )

    return {"analysis": response.final_output}


@app.post("/report")
async def report(request: Request):
    body = await request.json()

    prompt = f"""Generate a clinical-style report for a podiatrist based on this PressureMap session data.
Include: patient pressure distribution summary, biomechanical findings, longitudinal trends (if available),
and recommended follow-up. Use professional medical terminology but keep it readable.

Session data: {json.dumps(body)}
"""

    response = await runner.run(
        input=prompt,
        model="anthropic/claude-sonnet-4-20250514",
        tools=[analyze_pressure, compare_to_baseline],
    )

    return {"report": response.final_output}
```

### Running the Agent Server

```bash
uvicorn agent_server:app --host 0.0.0.0 --port 8000
```

For the hackathon demo, run this on your MacBook on the same WiFi as your iPhone. The iOS app hits `http://<macbook-ip>:8000/analyze`.

---

## iOS App Architecture

### Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **BLE:** CoreBluetooth
- **Charts:** Swift Charts (built-in iOS 16+)
- **Networking:** URLSession (hits Dedalus agent server)
- **Local Data:** SwiftData (session history)

### Project Structure

```
PressureMap/
├── App/
│   └── PressureMapApp.swift
├── Services/
│   ├── BLEManager.swift          # CoreBluetooth connection + data parsing
│   ├── CalibrationService.swift  # "Stand evenly" baseline capture
│   ├── AlertEngine.swift         # Sustained pressure monitoring
│   └── AgentClient.swift         # HTTPS calls to Dedalus agent server
├── Models/
│   ├── PressureReading.swift     # Timestamped 10-sensor reading
│   ├── FootMetrics.swift         # Computed biomechanical values
│   └── Session.swift             # SwiftData model for history
├── Views/
│   ├── HeatmapView.swift         # Real-time pressure heatmap (hero screen)
│   ├── DiagnosticScanView.swift  # 10-second capture + AI analysis
│   ├── ExerciseView.swift        # Live biofeedback during exercises
│   ├── GaitReplayView.swift      # Animated heatmap playback
│   ├── TrendsView.swift          # Longitudinal charts (Swift Charts)
│   └── ReportView.swift          # AI-generated podiatrist report
└── Utils/
    ├── HeatmapRenderer.swift     # Bilinear interpolation for 5-point heatmap
    └── ColorMap.swift             # Blue → Green → Yellow → Red pressure scale
```

### BLEManager (Core Code)

```swift
import CoreBluetooth
import Combine

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected = false
    @Published var leftReadings: [UInt16] = Array(repeating: 0, count: 5)
    @Published var rightReadings: [UInt16] = Array(repeating: 0, count: 5)

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var motorCharacteristic: CBCharacteristic?

    let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789abc")
    let sensorCharUUID = CBUUID(string: "abcdefab-1234-1234-1234-abcdefabcdef")
    let motorCharUUID = CBUUID(string: "abcdefab-1234-1234-1234-abcdefab0002")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // --- Motor Control ---

    /// Buzz the left insole motor for the given duration (10ms increments, max 255 = 2550ms)
    func buzzLeft(duration: UInt8 = 50) {
        sendMotorCommand(left: duration, right: 0)
    }

    /// Buzz the right insole motor
    func buzzRight(duration: UInt8 = 50) {
        sendMotorCommand(left: 0, right: duration)
    }

    /// Buzz both insoles simultaneously
    func buzzBoth(duration: UInt8 = 50) {
        sendMotorCommand(left: duration, right: duration)
    }

    private func sendMotorCommand(left: UInt8, right: UInt8) {
        guard let char = motorCharacteristic, let periph = peripheral else { return }
        let data = Data([left, right])
        periph.writeValue(data, for: char, type: .withResponse)
    }

    // --- BLE Lifecycle ---

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [serviceUUID])
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        peripheral.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else { return }
        peripheral.discoverCharacteristics([sensorCharUUID, motorCharUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in service.characteristics ?? [] {
            if char.uuid == sensorCharUUID {
                peripheral.setNotifyValue(true, for: char)
            } else if char.uuid == motorCharUUID {
                motorCharacteristic = char
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, data.count == 20 else { return }

        var readings: [UInt16] = []
        for i in stride(from: 0, to: 20, by: 2) {
            let value = UInt16(data[i]) << 8 | UInt16(data[i + 1])
            readings.append(value)
        }

        DispatchQueue.main.async {
            self.leftReadings = Array(readings[0..<5])
            self.rightReadings = Array(readings[5..<10])
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        motorCharacteristic = nil
        centralManager.scanForPeripherals(withServices: [serviceUUID])
    }
}
```

### AgentClient (Dedalus Integration)

```swift
class AgentClient {
    let baseURL: String  // e.g. "http://192.168.1.100:8000"

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func analyzeScan(left: [UInt16], right: [UInt16]) async throws -> String {
        let url = URL(string: "\(baseURL)/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "left_readings": left.map { Int($0) },
            "right_readings": right.map { Int($0) }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(AnalysisResponse.self, from: data)
        return result.analysis
    }

    func generateReport(sessionData: SessionData) async throws -> String {
        let url = URL(string: "\(baseURL)/report")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(sessionData)

        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(ReportResponse.self, from: data)
        return result.report
    }
}

struct AnalysisResponse: Decodable { let analysis: String }
struct ReportResponse: Decodable { let report: String }
```

### HeatmapRenderer (Bilinear Interpolation from 5 Points)

```swift
struct HeatmapRenderer {
    // Maps 5 discrete sensor values onto a foot-shaped grid using
    // inverse-distance-weighted interpolation

    struct SensorPosition {
        let x: CGFloat  // 0-1 normalized
        let y: CGFloat  // 0-1 normalized (0 = toe, 1 = heel)
    }

    static let sensorPositions: [SensorPosition] = [
        SensorPosition(x: 0.35, y: 0.15),  // S1: 1st metatarsal
        SensorPosition(x: 0.70, y: 0.20),  // S2: 5th metatarsal
        SensorPosition(x: 0.30, y: 0.50),  // S3: medial midfoot
        SensorPosition(x: 0.35, y: 0.85),  // S4: medial heel
        SensorPosition(x: 0.65, y: 0.85),  // S5: lateral heel
    ]

    static func interpolate(at point: CGPoint, values: [CGFloat]) -> CGFloat {
        var weightedSum: CGFloat = 0
        var totalWeight: CGFloat = 0

        for (i, sensor) in sensorPositions.enumerated() {
            let dx = point.x - sensor.x
            let dy = point.y - sensor.y
            let dist = sqrt(dx * dx + dy * dy)
            let weight = 1.0 / max(dist * dist, 0.001) // IDW
            weightedSum += weight * values[i]
            totalWeight += weight
        }

        return weightedSum / totalWeight
    }
}
```

### BiomechanicsAnalyzer (Local, Runs on Every Frame)

```swift
struct FootMetrics {
    let pronationIndex: Double    // >1.3 = overpronation
    let archIndex: Double         // >0.12 = flat foot concern
    let heelCentering: Double     // ~0.5 = centered
    let forefootBalance: Double   // ~0.55-0.65 = healthy

    var flatFootFlag: Bool { archIndex > 0.12 }
    var overpronationFlag: Bool { pronationIndex > 1.3 }
}

struct BiomechanicsAnalyzer {
    static func analyze(readings: [UInt16]) -> FootMetrics {
        let s = readings.map { Double($0) }
        let total = s.reduce(0, +)
        guard total > 0 else {
            return FootMetrics(pronationIndex: 1.0, archIndex: 0.0,
                             heelCentering: 0.5, forefootBalance: 0.5)
        }

        return FootMetrics(
            pronationIndex: (s[0] + s[2] + s[3]) / max(s[1] + s[4], 1),
            archIndex: s[2] / total,
            heelCentering: s[3] / max(s[3] + s[4], 1),
            forefootBalance: s[0] / max(s[0] + s[1], 1)
        )
    }
}
```

### AlertEngine (Sustained Pressure → Haptic Buzz)

```swift
class AlertEngine: ObservableObject {
    @Published var activeAlerts: [ZoneAlert] = []

    private var zonePressureTimers: [Int: Date] = [:]  // zone index → first-exceeded timestamp
    private let threshold: UInt16 = 2800  // ADC value (~70% of max, roughly 7kg on a single zone)
    private let durationLimit: TimeInterval = 15  // seconds for demo (production: 300+)
    private let bleManager: BLEManager

    struct ZoneAlert: Identifiable {
        let id = UUID()
        let zone: String
        let foot: String
        let duration: TimeInterval
    }

    init(bleManager: BLEManager) {
        self.bleManager = bleManager
    }

    /// Call this every frame (~50Hz) with the latest readings
    func evaluate(leftReadings: [UInt16], rightReadings: [UInt16]) {
        let zones = ["1st Met", "5th Met", "Med Midfoot", "Med Heel", "Lat Heel"]
        let allReadings = leftReadings + rightReadings
        let now = Date()

        for (i, value) in allReadings.enumerated() {
            if value > threshold {
                if let start = zonePressureTimers[i] {
                    let elapsed = now.timeIntervalSince(start)
                    if elapsed >= durationLimit {
                        // FIRE ALERT
                        let foot = i < 5 ? "Left" : "Right"
                        let zone = zones[i % 5]

                        activeAlerts.append(ZoneAlert(zone: zone, foot: foot, duration: elapsed))

                        // Trigger haptic motor on the offending foot
                        if i < 5 {
                            bleManager.buzzLeft(duration: 80)  // 800ms buzz
                        } else {
                            bleManager.buzzRight(duration: 80)
                        }

                        zonePressureTimers.removeValue(forKey: i)  // reset after alert
                    }
                } else {
                    zonePressureTimers[i] = now  // start timing
                }
            } else {
                zonePressureTimers.removeValue(forKey: i)  // pressure relieved, reset
            }
        }
    }
}
```

---

## Build Timeline (36 hours)

### Hour 0–8: Hardware + BLE Pipeline

| Time | Task |
|------|------|
| 0:00–2:00 | Wire mux breakout to ESP32: SIG→GPIO 36, S0–S3→GPIO 16–19, EN→GND, VCC→3.3V, GND→GND. Wire first FSR voltage divider, output to mux C0. Test with Serial.println to verify ADC reading through mux. |
| 2:00–4:00 | Wire remaining 9 FSR voltage dividers to mux C1–C9. Test all 10 channels with mux sweep sketch. Every sensor must respond independently. |
| 4:00–5:00 | Wire 2 motor driver circuits (transistor + flyback diode) on GPIO 25 and 26. Test each motor with manual GPIO HIGH. |
| 5:00–6:00 | Flash full BLE firmware. Verify BLE advertising, 50Hz sensor notify via mux, and motor write characteristic. Use nRF Connect to confirm both directions. |
| 6:00–7:00 | Mount FSRs + motors on foam insoles using Kapton tape. Route wires along insole edges. Test while standing. |
| 7:00–8:00 | BLEManager in iOS: scan, connect, parse 20-byte payload into 10 UInt16 values, write motor commands. Verify on-screen + motor buzz. |

### Hour 8–18: Core App + Dedalus Agent

| Time | Task |
|------|------|
| 8:00–11:00 | HeatmapView: real-time foot heatmap with IDW interpolation. Both feet side by side. This is the hero screen. |
| 11:00–13:00 | DiagnosticScanView: 10-second capture, local BiomechanicsAnalyzer processing, findings display. |
| 13:00–15:00 | Dedalus agent server: set up FastAPI + DedalusRunner with analyze_pressure and generate_rehab_plan tools. Test locally. |
| 15:00–18:00 | ExerciseView: short foot exercise with live target overlay. Show target zones in green, current pressure in color-mapped overlay. Score = how close current matches target. |

### Hour 18–28: Features + AI Integration

| Time | Task |
|------|------|
| 18:00–20:00 | AlertEngine: sustained pressure monitoring with configurable thresholds. Timer per zone. Triggers phone notification + haptic motor buzz via BLE write on breach. |
| 20:00–22:00 | GaitReplayView: record walking session (timestamped reading array), play back as animated heatmap with timeline scrubber. |
| 22:00–24:00 | TrendsView: load pre-generated 30-day longitudinal data. Render with Swift Charts. Weekly pronation index, arch index over time. |
| 24:00–26:00 | ReportView: iOS sends session data to agent /report endpoint. Display AI-generated podiatrist report. Add share/export. |
| 26:00–28:00 | UI polish. Consistent color palette. Loading states. Connection status indicator. BLE disconnect handling. |

### Hour 28–34: Integration + Demo Prep

| Time | Task |
|------|------|
| 28:00–30:00 | End-to-end testing. Stand on insoles → ESP32 → BLE → iPhone → heatmap → tap "Analyze" → Dedalus agent returns findings. Trigger pressure alert → motor buzzes. |
| 30:00–31:00 | Fix bugs. Recalibrate if needed. Replace any flaky sensor connections. |
| 31:00–33:00 | Build demo script (see below). Practice the 3-minute walkthrough. Time it. |
| 33:00–34:00 | Prepare fallback: if BLE fails at demo time, have a USB serial mode that streams data to a MacBook running a web-based heatmap. |

### Hour 34–36: Devpost + Submission

| Time | Task |
|------|------|
| 34:00–35:00 | Write Devpost submission. Screenshots of every screen. Photos of hardware. Architecture diagram. |
| 35:00–36:00 | Record 2-minute demo video as backup. Film yourself stepping on, showing heatmap, triggering AI analysis, showing report. |

---

## Demo Script (3 minutes)

**Minute 1 — Hook + Live Demo**

"130,000 Americans lose a foot to diabetes every year because they can't feel the pressure that causes ulcers. Clinical pressure mats cost $15,000. Ours costs $150, it vibrates to warn you, and it has an AI podiatrist built in."

Hand the insoles to the judge. They step on.

"That's your live pressure map. See how your weight distributes across your foot in real-time." Let them shift weight, watch the heatmap move.

**Minute 2 — Personal Story + AI Analysis**

"I have flat feet. Both my parents are diabetic. Let me show you what my feet look like."

Step on yourself. Point to the medial midfoot zone lighting up.

"See this zone? On a healthy foot it bears 0–5% of load. Mine is at 20%. That's my collapsed arch."

Tap "Analyze." The Dedalus agent processes in 2–3 seconds.

"Our AI agent just analyzed my biomechanics. It detected flat foot bilaterally, flagged overpronation on the left, and generated a personalized exercise plan with real-time biofeedback targets. Watch."

Switch to ExerciseView. Do a short foot exercise. The pressure shifts in real-time.

**Minute 3 — Diabetic Monitoring + Report**

Show the alert system. Stand still on one spot for the demo threshold (set to 15 seconds for demo).

Phone buzzes. Insole vibrates under your foot. Alert appears: "Sustained pressure on left 1st metatarsal. Shift weight."

"For a neuropathy patient, they didn't feel that pressure for 15 seconds. But they still feel vibration. Neuropathy kills pressure sensation first, but vibration perception survives longer. The motor detects what they can't feel and alerts them through a channel they still can."

Switch to ReportView. "The same AI agent generates a clinical report your podiatrist can actually use. Plain language, real metrics, exercise tracking."

**Close:** "10 sensors. 2 motors. $100 in parts. An AI agent that reads your feet. Fixes my arches. Protects my parents' feet."

---

## Track Eligibility

| Track | Fit |
|-------|-----|
| **Healthcare** | Primary. Diabetic neuropathy prevention, flat foot rehabilitation, AI-powered clinical analysis. |
| **Sustainability** | Stretch. Reducing medical waste from preventable amputations and hospital stays. |
| **Business & Enterprise** | Stretch. $150 vs $15,000 market disruption angle. |
| **Best Hardware Hack** | Strong. 10 FSR insoles + 2 haptic motors + ESP32 + BLE bidirectional + iOS app. |

### Sponsor Prizes to Target

- **Best Hardware Hack** — historically a strong standalone prize at HackPrinceton
- **Best Use of Dedalus Labs** — the AI agent layer is a genuine showcase of their SDK: multi-tool agent with MCP servers, local function tools, streaming, structured analysis
- **Capital One Best Financial Hack** — if you include a cost-savings calculator: "each prevented amputation saves $100K in medical costs"
- **MLH sponsor prizes** — Gemini API angle (swap model in Dedalus runner to `google/gemini-2.0-flash` for report generation)

---

## Why Dedalus Specifically

The Dedalus SDK isn't bolted on. It solves three real problems in this project:

1. **Provider-agnostic model routing.** During the hackathon, if Anthropic rate-limits you or Sonnet is slow, swap to `openai/gpt-4o` or `google/gemini-2.0-flash` in one line. No rewrite.

2. **MCP servers for medical context.** The agent connects to `brave-search` to look up clinical thresholds and reference literature in real-time. When it tells you "arch index > 0.15 indicates flat foot," it can cite the source.

3. **Local tool calling.** The `analyze_pressure`, `generate_rehab_plan`, and `compare_to_baseline` functions run locally as typed Python functions. Dedalus auto-extracts the schema and handles execution. The LLM decides when to call them based on the user's data.

Without Dedalus, you'd be manually calling OpenAI/Anthropic APIs, parsing JSON, handling tool calls yourself, and praying the model follows your function schema. Dedalus does all of that in 5 lines.

---

## References

- Diabetic foot pressure monitoring: Bus SA, et al. "Pressure relief and load redistribution by custom-made insoles" Clinical Biomechanics, 2004
- Flat foot classification via pressure: Queen RM, et al. "Describing the medial longitudinal arch using footprint indices and a clinical grading system" Foot & Ankle International, 2007
- FSR sensor applications: Interlink Electronics FSR 402 Integration Guide (force vs. resistance curves, voltage divider design)
- Healthy baseline pressure distributions: Cavanagh PR, et al. "Plantar pressure distribution in normal subjects" Journal of Biomechanics, 1987
- Dedalus Labs SDK: https://docs.dedaluslabs.ai/sdk/quickstart
