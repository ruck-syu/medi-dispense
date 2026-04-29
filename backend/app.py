import base64
import os
import tempfile
from pathlib import Path
from typing import Any

import joblib
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from gtts import gTTS
from pydantic import BaseModel, Field


class PredictionRequest(BaseModel):
    medicine_type: str = Field(..., min_length=1)
    total_doses: int = Field(..., ge=0)
    taken_doses: int = Field(..., ge=0)
    missed_doses: int = Field(..., ge=0)
    delay_minutes: int = Field(..., ge=0)
    adherence_percentage: float = Field(..., ge=0, le=100)
    scheduled_time: str = Field(..., min_length=1)
    language: str = Field(default="en", min_length=2, max_length=5)


class PredictionResponse(BaseModel):
    risk_level: str
    instruction_text: str
    audio_base64: str
    mime_type: str = "audio/mpeg"


class MedicineAiEngine:
    def __init__(self, model_dir: str) -> None:
        self.model_dir = Path(model_dir)
        self.model_path = self.model_dir / "medicine_pipeline.pkl"
        self.medicine_encoder_path = self.model_dir / "medicine_encoder.pkl"
        self.risk_encoder_path = self.model_dir / "risk_encoder.pkl"

        missing = [
            str(path.name)
            for path in [
                self.model_path,
                self.medicine_encoder_path,
                self.risk_encoder_path,
            ]
            if not path.exists()
        ]

        if missing:
            raise FileNotFoundError(
                "Missing model files: " + ", ".join(missing)
            )

        self.model = joblib.load(self.model_path)
        self.medicine_encoder = joblib.load(self.medicine_encoder_path)
        self.risk_encoder = joblib.load(self.risk_encoder_path)

    def required_files_status(self) -> dict[str, bool]:
        return {
            "medicine_pipeline.pkl": self.model_path.exists(),
            "medicine_encoder.pkl": self.medicine_encoder_path.exists(),
            "risk_encoder.pkl": self.risk_encoder_path.exists(),
        }

    def predict_risk(self, payload: PredictionRequest) -> str:
        medicine_value: Any = payload.medicine_type
        if self.medicine_encoder is not None:
            try:
                medicine_value = self.medicine_encoder.transform(
                    [payload.medicine_type]
                )[0]
            except Exception:
                medicine_value = payload.medicine_type

        row = {
            "medicine_type": medicine_value,
            "total_doses": payload.total_doses,
            "taken_doses": payload.taken_doses,
            "missed_doses": payload.missed_doses,
            "delay_minutes": payload.delay_minutes,
            "adherence_percentage": payload.adherence_percentage,
        }

        frame = pd.DataFrame([row])
        prediction: Any = self.model.predict(frame)[0]

        try:
            decoded = self.risk_encoder.inverse_transform([prediction])[0]
            return str(decoded).upper()
        except Exception:
            return str(prediction).upper()


def generate_instruction(medicine: str, scheduled_time: str, risk: str = "LOW") -> str:
    base = f"It is time to take your {medicine} medicine at {scheduled_time}. "

    if medicine == "BP":
        msg = (
            base
            + "Please take your blood pressure tablet now. "
            + "Drink one to two glasses of water. "
            + "Avoid salty and oily foods. "
            + "Take rest for at least 15 to 20 minutes. "
            + "Maintain a calm and stress-free environment. "
        )
    elif medicine == "Diabetes":
        msg = (
            base
            + "Please take your diabetes medicine now. "
            + "Eat your meal on time after taking medicine. "
            + "Avoid sugary foods and drinks. "
            + "Drink enough water. "
            + "Monitor your blood sugar regularly. "
        )
    elif medicine == "Fever":
        msg = (
            base
            + "Please take your fever tablet now. "
            + "Drink plenty of fluids like water or juice. "
            + "Take proper rest. "
            + "Avoid cold foods and stay warm. "
        )
    elif medicine == "Cough":
        msg = (
            base
            + "Please take your cough medicine now. "
            + "Drink warm water. "
            + "Avoid cold drinks and dust exposure. "
            + "Take proper rest. "
        )
    elif medicine == "Headache":
        msg = (
            base
            + "Please take your headache tablet now. "
            + "Take rest in a quiet place. "
            + "Avoid bright light and loud noise. "
            + "Drink enough water. "
        )
    elif medicine == "Cholesterol":
        msg = (
            base
            + "Please take your cholesterol medicine now. "
            + "Avoid oily and fatty foods. "
            + "Include healthy vegetables in your diet. "
            + "Do light physical activity regularly. "
        )
    elif medicine == "Asthma":
        msg = (
            base
            + "Please take your asthma medication now. "
            + "Avoid dust and allergens. "
            + "Keep your inhaler nearby. "
            + "Take rest if breathing is difficult. "
        )
    elif medicine == "Heart":
        msg = (
            base
            + "Please take your heart medication now. "
            + "Avoid stress and heavy activity. "
            + "Maintain a healthy diet. "
            + "Take proper rest. "
        )
    elif medicine == "Thyroid":
        msg = (
            base
            + "Please take your thyroid medicine now on an empty stomach. "
            + "Wait at least 30 minutes before eating. "
            + "Maintain a proper routine. "
        )
    elif medicine == "Pain Relief":
        msg = (
            base
            + "Please take your pain relief medicine now. "
            + "Take rest and avoid heavy physical activity. "
            + "Drink enough water. "
        )
    else:
        msg = (
            base
            + "Please take your medicine now. "
            + "Follow your routine and take care of your health. "
        )

    risk_upper = risk.upper()
    if risk_upper == "HIGH":
        msg += (
            "You have a high risk level. Please do not skip medicines and consult a doctor if needed. "
        )
    elif risk_upper == "MEDIUM":
        msg += "Try to follow your schedule properly and avoid missing doses. "
    else:
        msg += "Good job maintaining your schedule. Keep it up. "

    return msg


def synthesize_to_base64(text: str, language: str = "en") -> str:
    lang = language if language in {"en", "hi", "kn"} else "en"
    tts = gTTS(text=text, lang=lang)

    fd, tmp_path = tempfile.mkstemp(suffix=".mp3")
    os.close(fd)
    try:
        tts.save(tmp_path)
        audio = Path(tmp_path).read_bytes()
    finally:
        try:
            Path(tmp_path).unlink(missing_ok=True)
        except Exception:
            pass

    return base64.b64encode(audio).decode("utf-8")


MODEL_DIR = os.getenv("MODEL_DIR", str(Path(__file__).parent / "models"))

app = FastAPI(title="MediDispense AI API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup_event() -> None:
    app.state.startup_error = None
    app.state.ai_engine = None

    try:
        app.state.ai_engine = MedicineAiEngine(MODEL_DIR)
    except Exception as exc:
        app.state.startup_error = str(exc)


@app.get("/health")
def health() -> dict[str, Any]:
    engine = app.state.ai_engine

    if engine is not None:
        return {
            "status": "ok",
            "model_ready": True,
            "error": None,
            "model_1": {
                "ready": True,
                "message": "Random Forest model loaded",
            },
            "model_2": {
                "ready": True,
                "message": "Rule engine and gTTS ready",
            },
            "required_files": engine.required_files_status(),
        }

    model_dir = Path(MODEL_DIR)
    required_files = {
        "medicine_pipeline.pkl": (model_dir / "medicine_pipeline.pkl").exists(),
        "medicine_encoder.pkl": (model_dir / "medicine_encoder.pkl").exists(),
        "risk_encoder.pkl": (model_dir / "risk_encoder.pkl").exists(),
    }

    return {
        "status": "degraded",
        "model_ready": False,
        "error": app.state.startup_error,
        "model_1": {
            "ready": False,
            "message": "Risk model not loaded",
        },
        "model_2": {
            "ready": True,
            "message": "Rule engine and gTTS available",
        },
        "required_files": required_files,
    }


@app.post("/predict-instruction", response_model=PredictionResponse)
def predict_instruction(payload: PredictionRequest) -> PredictionResponse:
    engine = app.state.ai_engine
    if engine is None:
        raise HTTPException(
            status_code=503,
            detail=f"Model is not loaded: {app.state.startup_error}",
        )

    risk = engine.predict_risk(payload)
    instruction = generate_instruction(payload.medicine_type, payload.scheduled_time, risk)
    audio_base64 = synthesize_to_base64(instruction, payload.language)

    return PredictionResponse(
        risk_level=risk,
        instruction_text=instruction,
        audio_base64=audio_base64,
    )
