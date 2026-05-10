# environment_setup.md
# 원본 지우개 — ProPainter 환경 세팅

---

## 경로 A: 설치형 (ProPainter가 없는 PC)

**스크립트:** `setup_propainter.bat`

이 스크립트가 아래 전체를 자동 수행한다:
1. 전제조건 확인 (Git, Conda, ffmpeg)
2. ProPainter 저장소 clone
3. conda 환경 생성 (propainter / Python 3.8)
4. PyTorch 2.0.1 + CUDA 11.8 설치
5. requirements.txt 설치
6. GPU 선택 + CUDA 인식 확인
7. pyav 확인
8. weights 폴더 확인
9. 공식 샘플 확인
10. Quick Test 실행 + 결과 확인

### 실행 방법

```bat
REM 1. 작업 폴더 생성
mkdir C:\work
cd /d C:\work

REM 2. setup_propainter.bat 을 C:\work 에 넣는다

REM 3. Anaconda Prompt에서 실행
setup_propainter.bat
```

### 전제조건 (사람이 직접 설치)

| 항목 | 확인 명령 | 없으면 |
|---|---|---|
| Git | `git --version` | https://git-scm.com/download/win |
| Conda | `conda --version` | https://docs.conda.io/en/latest/miniconda.html |
| ffmpeg (권장) | `ffmpeg -version` | https://ffmpeg.org/download.html |
| NVIDIA 드라이버 | 장치관리자에서 GTX 1080 확인 | https://www.nvidia.com/Download/index.aspx |

### Quick Test 성공 기준

- `results\running_car\inpaint_out.mp4` 존재
- exit code 0
- OOM 없음

---

## 경로 B: 오버레이형 (ProPainter가 이미 설치된 PC)

**전제:** 경로 A를 통과했거나, 이미 ProPainter + conda env + Quick Test 통과 상태.

### 실행 방법

```bat
REM 1. ProPainter 루트로 이동
cd /d C:\work\ProPainter

REM 2. smoke test 패키지 압축 해제 후 복사
xcopy /E /Y "다운로드경로\propainter_smoke_test_v2\input" input\
copy /Y "다운로드경로\propainter_smoke_test_v2\run_smoke_test.bat" .
copy /Y "다운로드경로\propainter_smoke_test_v2\parameter_lock.json" .

REM 3. Phase 0 실행
run_smoke_test.bat 0

REM 4. Phase 1 실행
run_smoke_test.bat 1
```

`run_smoke_test.bat`이 자동으로 수행하는 것:
- conda activate propainter
- CUDA_VISIBLE_DEVICES=1 설정
- logs, output, results, input 폴더 자동 생성
- 전제조건 검사 (inference_propainter.py 존재, torch/CUDA 동작)
- 결과 파일 존재 여부 확인
- 실패 시 오류 분류 + 축소 재시도 명령 출력

---

## GPU 환경 정보

| 항목 | 값 |
|---|---|
| GPU | NVIDIA GeForce GTX 1080 (GPU 1) |
| VRAM | 8.0 GB |
| 아키텍처 | Pascal (sm_61) |
| 내장 GPU | Intel UHD Graphics 770 (GPU 0) |
| GPU 선택 | `set CUDA_VISIBLE_DEVICES=1` |
| PyTorch | 2.0.1+cu118 |
| Python | 3.8 |

---

## 스크립트 역할 분담

| 스크립트 | 용도 | 경로 |
|---|---|---|
| `setup_propainter.bat` | 설치형: clone → env → install → Quick Test | 경로 A |
| `run_smoke_test.bat` | 오버레이형: Phase 0/1 실행 | 경로 B |
| `run_smoke_test.sh` | 오버레이형 Linux/Mac 버전 | 경로 B |

---

## 알려진 문제

| 문제 | 증상 | 해결 |
|---|---|---|
| GPU 순서 | `get_device_name(0)` → Intel UHD | `set CUDA_VISIBLE_DEVICES=1` |
| sm_61 커널 없음 | `CUDA error: no kernel image` | PyTorch 2.0.1+cu118 사용 |
| av 설치 실패 | pip install av 실패 | `conda install av -c conda-forge` |
| timm 호환 | import 오류 | `pip install timm==0.6.13` |
| OOM | `CUDA out of memory` | fallback: 320x176, subvideo=30 |

---

*원본 지우개 실행개발팀 | 2026-05-10*
