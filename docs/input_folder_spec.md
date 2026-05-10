# input_folder_spec.md
# ProPainter 입력 폴더 구조 & 파일명 규칙
# 프로젝트: 원본 지우개 | 버전: v1.0 | 기준일: 2026-05-10

---

## 1. 개요

ProPainter는 두 가지 입력 모드를 지원한다.

| 모드 | 입력 | 비고 |
|---|---|---|
| **MP4 + 단일 마스크 PNG** | `.mp4` 파일 + 고정 영역 PNG 1장 | 자막 영역 고정 시 권장 |
| **프레임 폴더 + 마스크 폴더** | JPEG/PNG 프레임 시퀀스 + 동일 수의 마스크 PNG | 프레임별 마스크 제어 필요 시 |

**원본 지우개 1차 smoke test 기준: 공식 샘플 입력 → 사용자 7초 테스트 입력 순서로 진행**

---

## 2. 공식 샘플 입력 구조 (Phase 0 – Smoke Test)

ProPainter 저장소 클론 시 `inputs/` 폴더에 기본 포함.

```
ProPainter/
└── inputs/
    ├── object_removal/
    │   ├── bmx-trees/          ← JPEG 프레임 시퀀스 (00000.jpg ~ )
    │   │   ├── 00000.jpg
    │   │   ├── 00001.jpg
    │   │   └── ...
    │   └── bmx-trees_mask/     ← 동일 수의 PNG 마스크 (흰색=제거 영역)
    │       ├── 00000.png
    │       ├── 00001.png
    │       └── ...
    └── video_completion/
        ├── running_car.mp4     ← MP4 단일 파일 입력 샘플
        └── mask_square.png     ← 단일 마스크 PNG (전 프레임 공통 적용)
```

**smoke test 권장 명령 (가장 단순한 입력):**
```bash
python inference_propainter.py \
  --video inputs/video_completion/running_car.mp4 \
  --mask inputs/video_completion/mask_square.png \
  --height 240 --width 432 \
  --fp16 \
  --subvideo_length 50 \
  --neighbor_length 5 \
  --ref_stride 15
```

---

## 3. 사용자 7초 테스트 입력 구조 (Phase 1 – User Test)

### 3.1 폴더 위치 (고정)

```
ProPainter/
└── inputs_user/
    └── test_7s/
        ├── frames/             ← 원본 영상 프레임 시퀀스
        └── masks/              ← 자막 영역 마스크 시퀀스
```

### 3.2 파일명 규칙 (고정)

```
frames/
  00000.jpg   ← 5자리 제로패딩, .jpg 고정
  00001.jpg
  ...
  000N.jpg    ← 7초 × FPS 프레임 수 (예: 24fps → 168장)

masks/
  00000.png   ← 동일 네이밍, .png 고정, 8비트 grayscale
  00001.png
  ...
  000N.png
```

**규칙 요약:**
- 프레임 인덱스: 5자리 제로패딩 (`%05d` 포맷)
- 프레임 확장자: `.jpg` (JPEG, quality 95 권장)
- 마스크 확장자: `.png` (grayscale 8bit, 흰색=255=제거 영역, 검정=0=보존)
- frames/ 와 masks/ 의 파일 수가 **반드시 동일**해야 함
- 파일명 인덱스가 0부터 **연속적**이어야 함 (건너뜀 불가)

### 3.3 마스크 생성 방법 (자막 고정 영역)

**방법 A: Python 스크립트로 고정 자막 영역 마스크 생성 (권장)**

```python
# scripts/gen_subtitle_mask.py
import os
import numpy as np
from PIL import Image

# ======== 사용자 설정 영역 ========
FRAME_COUNT = 168          # 7초 × 24fps
FRAME_W = 432              # 출력 해상도 width
FRAME_H = 240              # 출력 해상도 height
OUTPUT_DIR = "inputs_user/test_7s/masks"

# 자막 위치 (픽셀 좌표, 원본 해상도 기준 → 리사이즈 후 비율 계산)
# 예: 하단 자막 영역 (전체 너비, 하단 20% 영역)
SUBTITLE_REGIONS = [
    # (x1, y1, x2, y2) - 좌상단, 우하단 픽셀 좌표 (리사이즈된 해상도 기준)
    (0, 192, 432, 240),    # 하단 자막 영역 (480x240 기준 하단 50px)
]
# =================================

os.makedirs(OUTPUT_DIR, exist_ok=True)

for i in range(FRAME_COUNT):
    mask = np.zeros((FRAME_H, FRAME_W), dtype=np.uint8)
    for (x1, y1, x2, y2) in SUBTITLE_REGIONS:
        mask[y1:y2, x1:x2] = 255
    img = Image.fromarray(mask, mode='L')
    img.save(os.path.join(OUTPUT_DIR, f"{i:05d}.png"))

print(f"마스크 생성 완료: {FRAME_COUNT}장 → {OUTPUT_DIR}/")
```

**방법 B: FFmpeg으로 원본 MP4에서 프레임 추출**

```bash
# 원본 7초 MP4가 있을 경우 프레임 추출
ffmpeg -i your_7s_video.mp4 \
  -vf "scale=432:240" \
  -q:v 2 \
  inputs_user/test_7s/frames/%05d.jpg

# 프레임 수 확인
ls inputs_user/test_7s/frames/ | wc -l
```

**방법 C: 공식 샘플 마스크 참조**

```
inputs/video_completion/mask_square.png 를 열어서
자막 위치에 맞게 흰색 영역 조정 후 복사
→ 단일 PNG 1장을 --mask 옵션으로 사용 (전 프레임 공통 적용)
```

---

## 4. 입력 검증 체크리스트

```bash
# [VALIDATE 1] 프레임 수 = 마스크 수 확인
FRAME_COUNT=$(ls inputs_user/test_7s/frames/*.jpg | wc -l)
MASK_COUNT=$(ls inputs_user/test_7s/masks/*.png | wc -l)
echo "프레임: $FRAME_COUNT, 마스크: $MASK_COUNT"
# 기대: 동일해야 함

# [VALIDATE 2] 첫 번째 파일 확인
ls inputs_user/test_7s/frames/00000.jpg
ls inputs_user/test_7s/masks/00000.png

# [VALIDATE 3] 마스크 형식 확인 (Python)
python -c "
from PIL import Image
import numpy as np
mask = Image.open('inputs_user/test_7s/masks/00000.png')
arr = np.array(mask)
print('Mode:', mask.mode)           # 기대: L (grayscale)
print('Shape:', arr.shape)          # 기대: (240, 432)
print('Unique values:', np.unique(arr))  # 기대: [0] 또는 [0, 255]
"

# [VALIDATE 4] 프레임 해상도 확인
python -c "
from PIL import Image
frame = Image.open('inputs_user/test_7s/frames/00000.jpg')
print('Size:', frame.size)   # 기대: (432, 240)
"
```

---

## 5. 단일 PNG 마스크 모드 (최간단 테스트)

공식 `video_completion` 샘플처럼 **단일 PNG 1장**을 전 프레임에 공통 적용 가능.

```bash
# 단일 마스크 PNG 생성 (Python)
python -c "
from PIL import Image, ImageDraw
import os

W, H = 432, 240
mask = Image.new('L', (W, H), 0)  # 검정 배경
draw = ImageDraw.Draw(mask)
# 하단 자막 영역 (하단 50px 흰색)
draw.rectangle([0, 190, 432, 240], fill=255)
os.makedirs('inputs_user/test_7s_single', exist_ok=True)
mask.save('inputs_user/test_7s_single/mask_subtitle.png')
print('마스크 생성 완료: inputs_user/test_7s_single/mask_subtitle.png')
"

# 실행 (MP4 + 단일 마스크)
python inference_propainter.py \
  --video inputs_user/test_7s_single/your_7s_video.mp4 \
  --mask inputs_user/test_7s_single/mask_subtitle.png \
  --height 240 --width 432 \
  --fp16 --subvideo_length 50 --neighbor_length 5 --ref_stride 15
```

---

## 6. 입력 우선순위 (원본 지우개 실행 순서)

```
우선순위 1: 공식 샘플 (video_completion)         → smoke test Phase 0
우선순위 2: 사용자 MP4 + 단일 마스크 PNG          → smoke test Phase 1a
우선순위 3: 사용자 프레임 폴더 + 마스크 폴더       → smoke test Phase 1b
```

---

*작성: 원본 지우개 실행개발팀 | 2026-05-10*
