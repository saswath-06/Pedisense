import json
import os
import google.generativeai as genai
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Tool Functions ---

def analyze_pressure(left_readings: list[int], right_readings: list[int]) -> dict:
    zones = ["1st_met", "5th_met", "med_midfoot", "med_heel", "lat_heel"]

    def compute(readings, side):
        total = sum(readings) or 1
        s1, s2, s3, s4, s5 = readings
        pron_denom = s2 + s5
        return {
            "side": side,
            "raw": dict(zip(zones, readings)),
            "pronation_index": round((s1 + s3 + s4) / pron_denom, 3) if pron_denom > 0 else 0,
            "arch_index": round(s3 / total, 3),
            "heel_centering": round(s4 / max(s4 + s5, 1), 3),
            "forefoot_balance": round(s1 / max(s1 + s2, 1), 3),
            "total_load": total
        }

    return {"left": compute(left_readings, "left"), "right": compute(right_readings, "right")}


def generate_rehab_plan(arch_index_left: float, arch_index_right: float,
                        pronation_index_left: float, pronation_index_right: float) -> list:
    exercises = []

    if arch_index_left > 0.12 or arch_index_right > 0.12:
        exercises.append({
            "name": "Short Foot Exercise",
            "description": "Sit with feet flat. Without curling toes, shorten your foot by pulling the ball toward the heel. Hold 5 seconds.",
            "sets": 3, "reps": 10, "frequency": "2x daily",
            "target_zone": "medial midfoot",
            "biofeedback_cue": "Watch medial midfoot sensor decrease as arch activates"
        })
        exercises.append({
            "name": "Towel Scrunches",
            "description": "Place towel on floor, scrunch toward you using only toes. Full extension between reps.",
            "sets": 3, "reps": 15, "frequency": "daily"
        })
        exercises.append({
            "name": "Heel Raises",
            "description": "Stand on both feet, slowly rise onto the balls of your feet, hold 2 seconds, lower slowly.",
            "sets": 3, "reps": 12, "frequency": "daily",
            "biofeedback_cue": "Weight should shift to 1st metatarsal zone during raise"
        })

    if pronation_index_left > 1.3 or pronation_index_right > 1.3:
        exercises.append({
            "name": "Single-Leg Balance (Lateral Focus)",
            "description": "Stand on one foot. Focus on keeping weight centered or slightly lateral. Use heel centering metric as biofeedback.",
            "sets": 3, "reps": "30 sec holds", "frequency": "daily",
            "biofeedback_cue": "Heel centering should trend toward 0.5"
        })
        exercises.append({
            "name": "Lateral Band Walks",
            "description": "Place resistance band around ankles. Walk sideways 10 steps each direction. Keep toes forward.",
            "sets": 3, "reps": "10 steps each direction", "frequency": "daily"
        })

    if not exercises:
        exercises.append({
            "name": "Maintenance: Calf Raises",
            "description": "Your biomechanics look healthy. Maintain with bilateral calf raises for ankle stability.",
            "sets": 3, "reps": 15, "frequency": "3x weekly"
        })

    return exercises


def compare_to_baseline(current_arch: float, baseline_arch: float,
                        current_pron: float, baseline_pron: float) -> dict:
    arch_change = current_arch - baseline_arch
    pron_change = current_pron - baseline_pron
    return {
        "arch_index_change": round(arch_change, 4),
        "arch_direction": "improving" if arch_change < 0 else "worsening" if arch_change > 0 else "stable",
        "pronation_change": round(pron_change, 4),
        "pronation_direction": "improving" if pron_change < 0 else "worsening" if pron_change > 0 else "stable"
    }


# --- Endpoints ---

@app.post("/analyze")
async def analyze(request: Request):
    try:
        body = await request.json()
        left = body["left_readings"]
        right = body["right_readings"]

        metrics = analyze_pressure(left, right)
        rehab = generate_rehab_plan(metrics)

        prompt = f"""You are a biomechanical analysis agent for Pedisense, a smart insole system that uses 10 force-sensing resistors (5 per foot) to map plantar pressure distribution in real-time.

Here are the computed metrics from a 10-second diagnostic scan:

LEFT FOOT:
- Raw sensor values (1st metatarsal, 5th metatarsal, medial midfoot, medial heel, lateral heel): {list(metrics['left']['raw'].values())}
- Arch Index: {metrics['left']['arch_index']} (normal: 0.00-0.05, flat foot: >0.12)
- Pronation Index: {metrics['left']['pronation_index']} (normal: 0.8-1.2, overpronation: >1.3)
- Heel Centering: {metrics['left']['heel_centering']} (ideal: 0.50, eversion: >0.60, inversion: <0.40)
- Forefoot Balance: {metrics['left']['forefoot_balance']} (ideal: 0.55-0.65)

RIGHT FOOT:
- Raw sensor values: {list(metrics['right']['raw'].values())}
- Arch Index: {metrics['right']['arch_index']}
- Pronation Index: {metrics['right']['pronation_index']}
- Heel Centering: {metrics['right']['heel_centering']}
- Forefoot Balance: {metrics['right']['forefoot_balance']}

Generated rehabilitation plan:
{json.dumps(rehab, indent=2)}

Provide a clinical interpretation of these results. Be specific, use the actual numbers, and write in plain language a patient can understand. Structure your response exactly as:

## Summary
Two sentences summarizing the overall findings.

## Findings
For each detected issue, explain what the metric means, what the patient's value is, what normal looks like, and what this means for their daily life.

## Recommended Exercises
List each exercise from the rehab plan above with a brief explanation of why it targets the specific issue found.

## For Your Podiatrist
A brief paragraph the patient can share with their podiatrist summarizing the key metrics."""

        model = genai.GenerativeModel("gemini-2.0-flash")
        response = model.generate_content(prompt)

        return {
            "analysis": response.text,
            "metrics": metrics,
            "exercises": rehab
        }
    except Exception as e:
        print(f"ERROR in /analyze: {e}")
        return {"error": str(e)}, 500