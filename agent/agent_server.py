import json
import os
from google import genai
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))


def analyze_pressure(left_readings, right_readings):
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


def generate_rehab_plan(metrics):
    exercises = []
    left = metrics["left"]
    right = metrics["right"]

    if left["arch_index"] > 0.12 or right["arch_index"] > 0.12:
        exercises.append({
            "name": "Short Foot Exercise",
            "description": "Sit with feet flat on the floor. Without curling your toes, try to shorten your foot by pulling the ball of the foot toward the heel, lifting the arch. Hold for 5 seconds.",
            "sets": 3, "reps": 10, "frequency": "2x daily"
        })
        exercises.append({
            "name": "Towel Scrunches",
            "description": "Place a towel on the floor. Using only your toes, scrunch the towel toward you. Fully extend toes between each rep.",
            "sets": 3, "reps": 15, "frequency": "daily"
        })
        exercises.append({
            "name": "Heel Raises",
            "description": "Stand with feet hip-width apart. Slowly rise onto your toes, hold for 2 seconds at the top, then lower back down.",
            "sets": 3, "reps": 12, "frequency": "daily"
        })

    if left["pronation_index"] > 1.3 or right["pronation_index"] > 1.3:
        exercises.append({
            "name": "Single-Leg Balance",
            "description": "Stand on one foot. Focus on keeping your weight centered or slightly toward the outer edge.",
            "sets": 3, "reps": "30 second holds", "frequency": "daily"
        })
        exercises.append({
            "name": "Lateral Band Walks",
            "description": "Place a resistance band around both ankles. Take 10 steps sideways in each direction, keeping tension on the band.",
            "sets": 3, "reps": "10 steps each direction", "frequency": "3x weekly"
        })

    if not exercises:
        exercises.append({
            "name": "Maintenance: Calf Raises",
            "description": "Your biomechanics look healthy. Maintain ankle stability with bilateral calf raises.",
            "sets": 3, "reps": 15, "frequency": "3x weekly"
        })

    return exercises


@app.get("/health")
async def health():
    return {"status": "ok", "service": "pedisense-agent"}


@app.post("/analyze")
async def analyze(request: Request):
    try:
        body = await request.json()
        left = body["left_readings"]
        right = body["right_readings"]

        metrics = analyze_pressure(left, right)
        rehab = generate_rehab_plan(metrics)

        prompt = f"""You are a biomechanical analysis agent for Pedisense, a smart insole system that uses 10 force-sensing resistors (5 per foot) to map plantar pressure distribution in real-time. Do NOT use any markdown formatting. No headers, no bold, no bullet points, no hashtags. Write in plain paragraphs with line breaks between sections. Use ALL CAPS for section titles instead of markdown headers.

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

Provide a clinical interpretation. Be specific, use actual numbers, write in plain language a patient can understand. Structure as:

## Summary
Two sentences summarizing findings.

## Findings
For each issue: what the metric means, patient's value, normal range, daily life impact.

## Recommended Exercises
Each exercise from the rehab plan with why it targets the issue.

## For Your Podiatrist
A brief paragraph the patient can share with their podiatrist summarizing the key metrics.

Do NOT use any markdown formatting. No headers, no bold, no bullet points, no hashtags. Write in plain paragraphs with line breaks between sections. Use ALL CAPS for section titles instead of markdown headers."""

        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )

        return {
            "analysis": response.text,
            "metrics": metrics,
            "exercises": rehab
        }
    except Exception as e:
        print(f"ERROR in /analyze: {e}")
        return {"error": str(e)}


@app.post("/report")
async def report(request: Request):
    try:
        body = await request.json()

        prompt = f"""Generate a clinical-style podiatry report based on this Pedisense smart insole session data.

Session data:
{json.dumps(body, indent=2)}

Structure as a formal medical document with:
1. Patient Assessment Summary
2. Plantar Pressure Distribution Analysis
3. Biomechanical Findings
4. Risk Assessment
5. Recommended Interventions
6. Follow-up Recommendations

Use professional medical terminology but keep it readable. Use professional medical terminology but keep it readable.

Do NOT use any markdown formatting. No headers, no bold, no bullet points, no hashtags. Write in plain paragraphs with line breaks between sections. Use ALL CAPS for section titles instead of markdown headers."""

        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )

        return {"report": response.text}
    except Exception as e:
        print(f"ERROR in /report: {e}")
        return {"error": str(e)}