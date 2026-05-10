# next_actions.md
# 원본 지우개 — 다음 액션

---

## 현재 상태

```
환경 문서:       ✅ environment_setup.md
입력 구조:       ✅ input_folder_spec.md
파라미터 잠금:   ✅ parameter_lock.json
실행 스크립트:   ✅ run_smoke_test.bat / .sh
결과 보고 양식:  ✅ result_report.md
실제 설치:       ⬜ 로컬 PC에서 미실행
Phase 0 실행:    ⬜ 미실행
Phase 1 실행:    ⬜ 미실행
```

---

## 즉시 수행 (로컬 PC)

### A1. 환경 세팅

```bat
conda create -n propainter python=3.8 -y
conda activate propainter
pip install torch==2.0.1+cu118 torchvision==0.15.2+cu118 --index-url https://download.pytorch.org/whl/cu118
git clone https://github.com/sczhou/ProPainter.git
cd ProPainter
pip install -r requirements.txt
```

### A2. GPU 인식 확인

```bat
set CUDA_VISIBLE_DEVICES=1
python -c "import torch; print(torch.cuda.get_device_name(0))"
```

GTX 1080이 출력되어야 한다.

### A3. Phase 0 실행

```bat
run_smoke_test.bat 0
```

### A4. 결과 기록

result_report.md의 Phase 0 섹션에 기입.

---

## Phase 0 PASS 후

### B1. 7초 테스트 영상 준비

```bat
mkdir input\video
mkdir input\masks
REM 7초 MP4를 input\video\test_input.mp4 으로 배치
```

### B2. 단일 마스크 생성

하단 자막 영역 고정 마스크 (432x240 기준):

```python
from PIL import Image, ImageDraw
mask = Image.new('L', (432, 240), 0)
draw = ImageDraw.Draw(mask)
draw.rectangle([0, 190, 432, 240], fill=255)  # 하단 50px
mask.save('input/masks/test_mask.png')
```

### B3. Phase 1 실행

```bat
run_smoke_test.bat 1
```

---

## Phase 0 FAIL 시

### OOM 발생

```bat
set CUDA_VISIBLE_DEVICES=1
python inference_propainter.py ^
  --video inputs/video_completion/running_car.mp4 ^
  --mask inputs/video_completion/mask_square.png ^
  --height 176 --width 320 --fp16 ^
  --subvideo_length 30 --neighbor_length 3 --ref_stride 20
```

### CUDA 오류 (sm_61)

```bat
pip install torch==1.13.1+cu118 torchvision==0.14.1+cu118 --index-url https://download.pytorch.org/whl/cu118
```

### av 패키지 오류

```bat
conda install av -c conda-forge
```

### 동일 오류 2회 반복 시

원인 분류를 result_report.md에 기록하고 총괄에게 보고.
Plan B 전환 검토.

---

## Phase 1 PASS 후 (품질 튜닝)

```
1차: 432x240, fp16, subvideo=50, neighbor=5, ref_stride=15  (현재)
2차: 432x240, fp16, subvideo=60, neighbor=7, ref_stride=10
3차: 432x240, fp16, subvideo=80, neighbor=10, ref_stride=10
4차: 720x480, fp16, subvideo=50, neighbor=5, ref_stride=15
```

---

*원본 지우개 실행개발팀 | 2026-05-10*
