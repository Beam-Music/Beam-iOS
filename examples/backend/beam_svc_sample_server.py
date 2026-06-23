from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel
from typing import Optional
import os
import tempfile
import uuid

app = FastAPI(title="Beam SVC Sample Server")

VOICE_REGISTRY = {
    "taylor_swift_singer": {
        "voiceId": "taylor_swift_singer",
        "name": "Taylor Swift Style",
        "category": "Western Pop Female",
        "description": "RVC sample voice",
        "preview_url": None,
        "language": ["en"],
        "voiceType": "singer",
    },
    "pNInz6obpgDQGcFmaJgB": {
        "voiceId": "pNInz6obpgDQGcFmaJgB",
        "name": "Adam",
        "category": "Default",
        "description": "Default sample voice",
        "preview_url": None,
        "language": ["en"],
        "voiceType": "default",
    },
}

class HealthResponse(BaseModel):
    ok: bool
    service: str
    version: str
    gpu: bool
    modelsLoaded: bool

@app.get("/ai-convert/health")
def health():
    return HealthResponse(
        ok=True,
        service="beam-svc",
        version="0.1.0",
        gpu=False,
        modelsLoaded=False,
    )

@app.get("/ai-convert/voices")
def voices():
    return {
        "voices": list(VOICE_REGISTRY.values()),
        "total_count": len(VOICE_REGISTRY),
    }

@app.post("/ai-convert/voice-conversion")
async def voice_conversion(
    source_audio: UploadFile = File(...),
    voiceId: str = Form(...),
    voiceType: Optional[str] = Form(None),
    language: str = Form("en"),
    preserve_melody: str = Form("true"),
    mix_with_instrumental: str = Form("true"),
    output_format: str = Form("mp3"),
):
    if voiceId not in VOICE_REGISTRY:
        raise HTTPException(status_code=404, detail={"error": "voice_not_found", "message": f"Unknown voiceId: {voiceId}"})

    audio_bytes = await source_audio.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail={"error": "empty_audio", "message": "source_audio is empty"})
    if len(audio_bytes) > 25 * 1024 * 1024:
        raise HTTPException(status_code=413, detail={"error": "file_too_large", "message": "Max 25MB"})

    with tempfile.TemporaryDirectory(prefix="beam_svc_") as workdir:
        input_path = os.path.join(workdir, f"input_{uuid.uuid4().hex}.bin")
        with open(input_path, "wb") as f:
            f.write(audio_bytes)

        # Sample stub only.
        # Replace this block with:
        # 1) demucs separation
        # 2) RMVPE F0 extraction
        # 3) HuBERT/ContentVec features
        # 4) RVC inference
        # 5) remix + encode
        converted_audio = audio_bytes

        media_type = {
            "mp3": "audio/mpeg",
            "wav": "audio/wav",
            "m4a": "audio/mp4",
        }.get(output_format, "audio/mpeg")

        return Response(content=converted_audio, media_type=media_type)

@app.exception_handler(HTTPException)
async def http_exception_handler(_, exc: HTTPException):
    if isinstance(exc.detail, dict):
        return JSONResponse(status_code=exc.status_code, content=exc.detail)
    return JSONResponse(status_code=exc.status_code, content={"error": "http_error", "message": str(exc.detail)})
