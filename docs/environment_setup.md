# environment_setup.md
# ProPainter 로컬 실행 환경 구성 가이드
# 프로젝트: 원본 지우개 | 버전: v1.0 | 기준일: 2026-05-10

---

## 1. 대상 하드웨어 사양 (확인 완료)

| 항목 | 사양 |
|---|---|
| GPU 모델 | NVIDIA GeForce GTX 1080 |
| VRAM | 8.0 GB 전용 |
| 드라이버 버전 | 31.0.15.2849 (2023-02-02) |
| DirectX | 12 (FL 12.1) |
| 보조 GPU | Intel UHD Graphics 770 (CPU 내장, CUDA 미지원) |
| RAM | 15.8 GB |
| OS | Windows 11 (한국어) |

**CUDA 아키텍처**: GTX 1080 = Pascal (sm_61)  
**지원 CUDA 최대 버전**: 드라이버 31.0.15.2849 → CUDA 12.x 지원  
**권장 CUDA 설치 버전**: CUDA 11.8 (PyTorch 안정 호환 최적)

---

## 2. 소프트웨어 스택 (고정 결정)

```
Python      : 3.8.x (Conda 환경)
PyTorch     : 1.13.1+cu118 (CUDA 11.8 빌드) 또는 2.0.1+cu118
Torchvision : 0.14.1+cu118 또는 0.15.2+cu118
CUDA        : 11.8
cuDNN       : 8.7.x (CUDA 11.8 대응)
```

> **왜 PyTorch 1.13.1인가?**  
> GTX 1080 (Pascal / sm_61)은 PyTorch 2.x의 FlashAttention과 일부 커널에서  
> sm_61 미지원 오류가 발생할 수 있음. 1.13.1은 sm_61 공식 지원이 확인됨.  
> 단, PyTorch 2.0.1+cu118도 sm_61 기본 지원 → 실패 시 1.13.1로 다운그레이드.

---

## 3. 설치 단계 (Windows / Linux 겸용 표기)

### Step 1: CUDA 11.8 설치 (Windows)

```
1. https://developer.nvidia.com/cuda-11-8-0-download-archive 접속
2. Windows → x86_64 → 11 → exe(local) 선택
3. 다운로드 후 설치 (Express 설치 권장)
4. 설치 후 확인:
   nvcc --version
   → CUDA compilation tools, release 11.8
```

### Step 2: Conda 환경 생성

```bash
# Conda 설치 없을 경우: https://docs.anaconda.com/miniconda/ 에서 설치
conda create -n propainter python=3.8 -y
conda activate propainter
```

### Step 3: PyTorch 설치 (CUDA 11.8)

```bash
# 옵션 A: PyTorch 2.0.1 (권장 시작점)
pip install torch==2.0.1+cu118 torchvision==0.15.2+cu118 --index-url https://download.pytorch.org/whl/cu118

# 옵션 B: PyTorch 1.13.1 (OOM 또는 sm_61 오류 시 폴백)
pip install torch==1.13.1+cu118 torchvision==0.14.1+cu118 --index-url https://download.pytorch.org/whl/cu118

# 설치 확인
python -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_name(0))"
# 기대 출력: 2.0.1+cu118 True NVIDIA GeForce GTX 1080
```

### Step 4: ProPainter 저장소 클론

```bash
# 작업 디렉터리 기준 (예: D:\projects\)
cd D:\projects
git clone https://github.com/sczhou/ProPainter.git
cd ProPainter
```

### Step 5: 의존성 패키지 설치

```bash
# conda 환경 활성화 확인 후
conda activate propainter

# ProPainter requirements 설치
pip install -r requirements.txt

# requirements.txt 내용 (확인된 목록):
# av, addict, einops, future, numpy, scipy, opencv-python,
# matplotlib, scikit-image, torch>=1.7.1, torchvision>=0.8.2,
# imageio-ffmpeg, pyyaml, requests, timm, yapf

# 혹시 av 설치 실패 시:
pip install av --no-binary av
# 또는
conda install av -c conda-forge
```

### Step 6: Weights 준비

```bash
# 방법 A: 자동 다운로드 (첫 inference 실행 시 자동)
# → 인터넷 연결 상태에서 아래 smoke test 명령 실행 시 자동 다운로드

# 방법 B: 수동 다운로드 (인터넷 불안정 시)
# GitHub Releases: https://github.com/sczhou/ProPainter/releases/tag/v0.1.0
# 다운로드 대상:
#   - ProPainter.pth         (~280 MB)
#   - recurrent_flow_completion.pth (~50 MB)
#   - raft-things.pth        (~21 MB)
# 저장 위치: ProPainter/weights/

mkdir weights
# 수동으로 위 3개 파일을 weights/ 폴더에 위치
```

**weights 폴더 최종 구조:**
```
ProPainter/
└── weights/
    ├── ProPainter.pth
    ├── recurrent_flow_completion.pth
    ├── raft-things.pth
    └── README.md
```

### Step 7: FFmpeg 확인

```bash
# imageio-ffmpeg 설치로 내장 ffmpeg 사용 가능
# 별도 설치 필요 없음 (imageio-ffmpeg 자동 처리)

# 확인
python -c "import imageio; print(imageio.plugins.ffmpeg.get_exe())"
```

---

## 4. 설치 검증 체크리스트

```bash
# 아래 명령을 순서대로 실행, 모두 통과해야 smoke test 진행 가능

# [CHECK 1] Python 버전
python --version
# 기대: Python 3.8.x

# [CHECK 2] CUDA 가용성
python -c "import torch; print('CUDA:', torch.cuda.is_available())"
# 기대: CUDA: True

# [CHECK 3] GPU 인식
python -c "import torch; print(torch.cuda.get_device_name(0))"
# 기대: NVIDIA GeForce GTX 1080

# [CHECK 4] VRAM 확인
python -c "import torch; print('VRAM:', torch.cuda.get_device_properties(0).total_memory/1024**3, 'GB')"
# 기대: VRAM: ~8.0 GB

# [CHECK 5] 주요 패키지 임포트
python -c "import cv2; import einops; import timm; print('OK')"
# 기대: OK

# [CHECK 6] weights 존재 확인 (PowerShell)
Test-Path .\weights\ProPainter.pth
Test-Path .\weights\recurrent_flow_completion.pth
Test-Path .\weights\raft-things.pth
# 기대: True True True
```

---

## 5. 알려진 이슈 및 대처

| 이슈 | 원인 | 대처 |
|---|---|---|
| `CUDA error: no kernel image for sm_61` | PyTorch 버전 미호환 | PyTorch 1.13.1+cu118로 다운그레이드 |
| `av` 패키지 빌드 실패 | Windows 컴파일러 없음 | `conda install av -c conda-forge` |
| OOM (Out of Memory) | VRAM 8GB 초과 | parameter_lock.json 설정 적용 (subvideo_length=50, fp16) |
| weights 자동 다운로드 실패 | 네트워크 | 수동 다운로드 후 weights/ 배치 |
| `timm` ImportError | 버전 충돌 | `pip install timm==0.6.13` |

---

## 6. 디렉터리 최종 구조 (설치 완료 후)

```
D:\projects\ProPainter\
├── inference_propainter.py     ← 메인 실행 스크립트
├── requirements.txt
├── weights/
│   ├── ProPainter.pth
│   ├── recurrent_flow_completion.pth
│   └── raft-things.pth
├── inputs/
│   ├── object_removal/
│   │   ├── bmx-trees/          ← 공식 샘플 프레임 폴더
│   │   └── bmx-trees_mask/     ← 공식 샘플 마스크 폴더
│   └── video_completion/
│       ├── running_car.mp4     ← 공식 샘플 MP4
│       └── mask_square.png     ← 공식 샘플 단일 마스크
├── results/                    ← 출력 결과 저장 위치
└── inputs_user/                ← 사용자 7초 테스트 입력 (별도 spec 참조)
    └── test_7s/
        ├── frames/
        └── masks/
```

---

*작성: 원본 지우개 실행개발팀 | 2026-05-10*
