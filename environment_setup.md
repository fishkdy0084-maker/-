# environment_setup.md
# 원본 지우개 — ProPainter 실행 환경 세팅 가이드
# 대상: GTX 1080 8GB / Windows / Plan A

---

## 대상 환경 (GPU 이미지에서 확인된 사실)

| 항목 | 값 |
|---|---|
| GPU | NVIDIA GeForce GTX 1080 (GPU 1) |
| VRAM | 8.0 GB 전용 |
| 드라이버 버전 | 31.0.15.2849 |
| 드라이버 날짜 | 2023-02-02 |
| DirectX | 12 (FL 12.1) |
| PCI 위치 | Bus 1, Device 0, Function 0 |
| 내장 GPU | Intel UHD Graphics 770 (GPU 0) — 사용 안 함 |
| OS | Windows (작업 관리자 확인) |

---

## Step 1. Miniconda 설치

이미 conda가 있으면 건너뛴다.

```
다운로드: https://docs.conda.io/en/latest/miniconda.html
설치 후 확인:
  conda --version
```

---

## Step 2. conda 환경 생성

```bat
conda create -n propainter python=3.8 -y
conda activate propainter
```

Python 3.8을 사용한다. ProPainter는 3.8~3.10에서 동작 확인됨.

---

## Step 3. PyTorch + CUDA 설치

GTX 1080은 Pascal 아키텍처(sm_61)이다.
CUDA 11.8 + PyTorch 2.0.1 조합을 권장한다.

```bat
pip install torch==2.0.1+cu118 torchvision==0.15.2+cu118 --index-url https://download.pytorch.org/whl/cu118
```

### 설치 후 검증

```bat
python -c "import torch; print(torch.__version__); print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"
```

기대 출력:
```
2.0.1+cu118
True
NVIDIA GeForce GTX 1080
```

만약 `torch.cuda.get_device_name(0)`이 Intel UHD를 반환하면,
GPU 0이 내장 GPU로 잡힌 것이다. 아래로 확인:

```bat
python -c "import torch; print(torch.cuda.device_count()); [print(i, torch.cuda.get_device_name(i)) for i in range(torch.cuda.device_count())]"
```

GTX 1080이 device 1이면, 환경변수로 지정:
```bat
set CUDA_VISIBLE_DEVICES=1
```

---

## Step 4. ProPainter 클론

```bat
git clone https://github.com/sczhou/ProPainter.git
cd ProPainter
```

---

## Step 5. 의존성 설치

```bat
pip install -r requirements.txt
```

requirements.txt 내용 (실제 확인됨):
```
av
addict
einops
future
numpy
scipy
opencv-python
matplotlib
scikit-image
torch>=1.7.1
torchvision>=0.8.2
imageio-ffmpeg
pyyaml
requests
timm
yapf
```

### av 패키지 설치 실패 시

Windows에서 `av` (PyAV)가 pip로 안 되는 경우:
```bat
conda install av -c conda-forge
```

### timm 버전 주의

ProPainter는 timm을 사용한다. 최신 timm과 호환 문제가 있을 수 있으므로:
```bat
pip install timm==0.6.13
```

---

## Step 6. Weights 확인

첫 실행 시 자동 다운로드된다.
실패하면 수동 다운로드:

```
https://github.com/sczhou/ProPainter/releases/download/v0.1.0/ProPainter.pth
https://github.com/sczhou/ProPainter/releases/download/v0.1.0/recurrent_flow_completion.pth
https://github.com/sczhou/ProPainter/releases/download/v0.1.0/raft-things.pth
```

다운로드 후 `weights/` 폴더에 배치:
```
ProPainter/
  weights/
    ProPainter.pth
    recurrent_flow_completion.pth
    raft-things.pth
```

---

## Step 7. 공식 샘플로 설치 검증

```bat
cd ProPainter
python inference_propainter.py --video inputs/video_completion/running_car.mp4 --mask inputs/video_completion/mask_square.png --height 240 --width 432 --fp16
```

성공 시:
```
results/running_car/masked_in.mp4
results/running_car/inpaint_out.mp4
```

---

## 검증 체크리스트

| # | 항목 | 확인 방법 | 통과 기준 |
|---|---|---|---|
| 1 | Python 버전 | `python --version` | 3.8.x |
| 2 | torch 임포트 | `python -c "import torch"` | 오류 없음 |
| 3 | CUDA 사용 가능 | `python -c "import torch; print(torch.cuda.is_available())"` | True |
| 4 | GPU 이름 | `python -c "import torch; print(torch.cuda.get_device_name(0))"` | GTX 1080 |
| 5 | fp16 동작 | `python -c "import torch; torch.zeros(1).half().cuda()"` | 오류 없음 |
| 6 | av 임포트 | `python -c "import av"` | 오류 없음 |
| 7 | weights 존재 | `dir weights\*.pth` | 3개 파일 |
| 8 | 공식 샘플 존재 | `dir inputs\video_completion\running_car.mp4` | 파일 존재 |

---

## 알려진 문제 및 대처

### 문제 1: CUDA device 순서

시스템에 Intel UHD(GPU 0) + GTX 1080(GPU 1)이 있다.
torch가 Intel을 먼저 잡을 수 있다.

```bat
set CUDA_VISIBLE_DEVICES=1
```

을 실행 스크립트에 포함시킨다.

### 문제 2: sm_61 커널 없음

```
CUDA error: no kernel image is available for execution on the device
```

PyTorch 2.0.1+cu118로 해결된다.
그래도 발생하면 fallback:
```bat
pip install torch==1.13.1+cu118 torchvision==0.14.1+cu118 --index-url https://download.pytorch.org/whl/cu118
```

### 문제 3: OOM

parameter_lock.json의 보수 파라미터를 사용한다.
그래도 OOM이면 fallback 파라미터를 적용한다.

---

*원본 지우개 실행개발팀 | 2026-05-10*
