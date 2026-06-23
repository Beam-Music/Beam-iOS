# Backend Examples

## Beam SVC sample server
File:
- `examples/backend/beam_svc_sample_server.py`

Run:
```bash
pip install fastapi uvicorn python-multipart
uvicorn examples.backend.beam_svc_sample_server:app --reload --port 8081
```

This is a stub server for iOS integration only.
Replace the conversion block with real:
- Demucs
- RMVPE
- HuBERT/ContentVec
- RVC inference
- remix/encode
