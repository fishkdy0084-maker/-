# 원본 지우개 - ProPainter 실행 패키지

> 중국 원본 영상 자막/글자 제거 | GTX 1080 8GB 기준 7초 smoke test 구성

---

## 프로젝트 목적

GTX 1080 8GB 환경에서 ProPainter를 사용해 7초짜리 영상의 자막/글자를 제거하는 **smoke test를 실행 가능한 상태**로 만드는 것.

- **범위**: 7초 테스트 1회 성공 확인
- **비범위**: 본편 자동화, 대규모 파이프라인, Happy Horse 사용

---

## 디렉터리 구조

```
원본지우개/
├── README.md                     ← 이 파일
├── parameter_lock.json           ← GTX 1080 8GB 안전 파라미터 (변경 금지)
├── docs/
│   ├── environment_setup.md      ← 설치 가이드 (CUDA/PyTorch/ProPainter)
│   ├── input_folder_spec.md      ← 입력 폴더 구조 규칙
│   ├── result_report.md          ← 실행 결과 보고서 템플릿
│   └── next_actions.md           ← 다음 단계 액션 플랜
└── scripts/
    ├── run_smoke_test.sh         ← Smoke Test 실행 (Linux/Mac)
    ├── run_smoke_test.bat        ← Smoke Test 실행 (Windows)
    ├── check_env.py              ← 환경 자동 점검
    ├── gen_subtitle_mask.py      ← 자막 마스크 생성
    └── extract_frames.sh         ← MP4에서 프레임 추출
```

---

## 즉시 시작 (Quick Start)

### 1. ProPainter 설치

```bash
# 1. CUDA 11.8 설치 (https://developer.nvidia.com/cuda-11-8-0-download-archive)
# 2. Conda 환경 생성
conda create -n propainter python=3.8 -y
conda activate propainter

# 3. PyTorch 설치 (CUDA 11.8)
pip install torch==2.0.1+cu118 torchvision==0.15.2+cu118 \
  --index-url https://download.pytorch.org/whl/cu118

# 4. ProPainter 클론
git clone https://github.com/sczhou/ProPainter.git
cd ProPainter

# 5. 의존성 설치
pip install -r requirements.txt

# 6. 이 패키지의 scripts/ 복사
cp -r /path/to/이패키지/scripts/ .
cp /path/to/이패키지/parameter_lock.json .
```

### 2. 환경 점검

```bash
# ProPainter 폴더에서 실행
python scripts/check_env.py
```

### 3. Smoke Test Phase 0 (공식 샘플)

```bash
# Windows
scripts\run_smoke_test.bat 0

# Linux/Mac
bash scripts/run_smoke_test.sh 0
```

### 4. 사용자 7초 테스트

```bash
# 영상 준비
bash scripts/extract_frames.sh your_video.mp4 0 7

# 마스크 생성 (scripts/gen_subtitle_mask.py 수정 후)
python scripts/gen_subtitle_mask.py

# 실행
bash scripts/run_smoke_test.sh 1a  # MP4 + 단일 마스크
bash scripts/run_smoke_test.sh 1b  # 프레임 폴더 모드
```

---

## 핵심 파라미터 (GTX 1080 8GB 고정값)

| 파라미터 | 값 | 이유 |
|---|---|---|
| `--width` | 432 | 공식 학습 해상도, VRAM 최소화 |
| `--height` | 240 | 공식 학습 해상도, VRAM 최소화 |
| `--fp16` | 활성화 | VRAM 40% 절감 |
| `--subvideo_length` | 50 | OOM 방지 (기본 80 → 50) |
| `--neighbor_length` | 5 | VRAM 절감 (기본 10 → 5) |
| `--ref_stride` | 15 | 참조 프레임 감소 (기본 10 → 15) |

예상 VRAM: **~3-4 GB** (GTX 1080 8GB 안전 범위)

---

## 문서 참조

| 문서 | 내용 |
|---|---|
| [environment_setup.md](docs/environment_setup.md) | CUDA/PyTorch/ProPainter 설치 전체 절차 |
| [input_folder_spec.md](docs/input_folder_spec.md) | 입력 폴더 구조 및 파일명 규칙 |
| [parameter_lock.json](parameter_lock.json) | 고정 파라미터 + 폴백 파라미터 |
| [result_report.md](docs/result_report.md) | 실행 결과 기록 템플릿 |
| [next_actions.md](docs/next_actions.md) | 다음 액션 플랜 |

---

## 기술 제약 (고정 결정사항)

1. **ProPainter 사용** (Happy Horse 미사용)
2. **현재 목표**: 7초 테스트 1회 성공 (본편 자동화 아님)
3. **메모리 안정성 우선**: 품질보다 OOM 없는 실행 완료
4. **저해상도 시작**: 432×240 고정

---

*원본 지우개 실행개발팀 | 2026-05-10*
