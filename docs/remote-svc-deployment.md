# Remote Beam SVC deployment

## 목표
- `beam-server-nest`: 로컬/일반 API 서버 (`:8080`)
- `beam-svc-server`: 원격 Linux GPU 서버 (`:8081`)
- iOS 앱은 계속 Nest만 호출

## 구조
- iOS App -> `beam-server-nest`
- `beam-server-nest` -> `BEAM_SVC_URL`
- `BEAM_SVC_URL` -> remote `beam-svc-server`

## 1. GPU 서버 준비
권장:
- Ubuntu 22.04+
- NVIDIA GPU
- CUDA 가능한 드라이버
- Python 3.10
- ffmpeg
- git

예시 패키지:
```bash
sudo apt update
sudo apt install -y git ffmpeg python3.10 python3.10-venv python3-pip
```

## 2. 소스 배치
서버에 아래 2개를 올립니다.
- `beam-svc-server`
- `beam-voice-conversion/Retrieval-based-Voice-Conversion-WebUI`

## 3. RVC 런타임 설치
`Retrieval-based-Voice-Conversion-WebUI`에서:
```bash
python3.10 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip install -r requirements/main.txt
```

## 4. 모델 배치
`beam-svc-server/model_registry/voices.json` 기준으로 아래 파일이 있어야 합니다.
- `weights/rvc/<voice>/model.pth`
- `weights/rvc/<voice>/added.index`

## 5. beam-svc-server 설정
`beam-svc-server/.env` 예시:
```bash
BEAM_RVC_REPO=/home/ubuntu/beam/beam-voice-conversion/Retrieval-based-Voice-Conversion-WebUI
BEAM_RVC_PYTHON=/home/ubuntu/beam/beam-voice-conversion/Retrieval-based-Voice-Conversion-WebUI/.venv/bin/python
BEAM_DEMUCS_COMMAND=demucs
BEAM_FFMPEG_COMMAND=ffmpeg
BEAM_FFPROBE_COMMAND=ffprobe
BEAM_RVC_DEVICE=cuda:0
BEAM_RVC_IS_HALF=true
BEAM_RVC_F0_METHOD=rmvpe
```

## 6. startup log checklist
1. `uvicorn app.main:app --host 0.0.0.0 --port 8081` 시작
2. 로그에 `Application startup complete` / `Uvicorn running on http://0.0.0.0:8081` 확인
3. `GET /ai-convert/health` 가 `ok=true` 인지 확인
4. `GET /ai-convert/voices` 에서 `total_count >= 1` 확인
5. `ok=false`면 doctor 확인: `rvc_repo_exists`, `infer_cli_exists`, `rvc_python_exists`, `ffmpeg_exists`, `ffprobe_exists`, `demucs_exists`, `at_least_one_model_exists`

## 7. 서버 상태 확인
```bash
curl http://127.0.0.1:8081/ai-convert/health
curl http://127.0.0.1:8081/ai-convert/voices
```

## 8. Nest 서버 연결
`beam-server-nest/.env`:
```bash
PORT=8080
BEAM_SVC_URL=http://YOUR_GPU_SERVER_IP:8081
```

실행:
```bash
cd beam-server-nest
npm install
PORT=8080 npm run start:dev
```

확인:
```bash
curl http://127.0.0.1:8080/ai-convert/health
curl http://127.0.0.1:8080/ai-convert/voices
```

## 9. iOS 앱 설정
시뮬레이터 기준:
```xml
<key>BEAM_API_BASE_URL</key>
<string>http://127.0.0.1:8080</string>
<key>BEAM_SVC_BASE_URL</key>
<string>http://127.0.0.1:8081</string>
```

실제 앱은 주로 Nest(`BEAM_API_BASE_URL`)만 쓰면 됩니다.

## 10. 운영 팁
- beam-svc-server는 `tmux`, `screen`, `systemd` 중 하나로 백그라운드 실행
- GPU 서버 방화벽에서 `8081` 허용
- 가능하면 `nginx` 뒤에 두고 HTTPS 적용
- 대용량/full-track 변환은 async job 사용
