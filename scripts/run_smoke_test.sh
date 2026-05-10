#!/usr/bin/env bash
# =============================================================================
# run_smoke_test.sh
# 프로젝트: 원본 지우개
# 목적: GTX 1080 8GB에서 ProPainter smoke test 실행
# 버전: v1.0 | 기준일: 2026-05-10
# =============================================================================
# 사용법:
#   chmod +x run_smoke_test.sh
#   ./run_smoke_test.sh
#
# 사전 요건:
#   1. conda 환경 'propainter' 활성화 상태
#   2. ProPainter 저장소 루트에서 실행
#   3. weights/ 폴더에 모델 파일 존재 (또는 첫 실행 시 자동 다운로드)
#   4. CUDA 11.8 + PyTorch 2.0.1+cu118 설치 완료
# =============================================================================

set -e  # 오류 발생 시 즉시 중단

# ─── 색상 출력 ───────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  원본 지우개 - ProPainter Smoke Test Runner${NC}"
echo -e "${CYAN}  대상 GPU: GTX 1080 8GB | 파라미터: parameter_lock.json 기준${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# ─── 파라미터 고정값 (parameter_lock.json 기준) ──────────────────────────────
WIDTH=432
HEIGHT=240
FP16="--fp16"
SUBVIDEO_LENGTH=50
NEIGHBOR_LENGTH=5
REF_STRIDE=15

# ─── 실행 단계 선택 ──────────────────────────────────────────────────────────
PHASE="${1:-0}"   # 인자 없으면 Phase 0 (공식 샘플)

# ─── STEP 0: 환경 체크 ───────────────────────────────────────────────────────
echo -e "${BLUE}[STEP 0] 환경 체크 시작...${NC}"

# Python 확인
PYTHON_VER=$(python --version 2>&1)
echo "  Python: $PYTHON_VER"

# CUDA 확인
CUDA_OK=$(python -c "import torch; print('OK' if torch.cuda.is_available() else 'FAIL')" 2>/dev/null || echo "IMPORT_FAIL")
if [ "$CUDA_OK" != "OK" ]; then
    echo -e "${RED}  [FAIL] CUDA 불가 또는 torch 임포트 실패${NC}"
    echo -e "${RED}  → conda activate propainter 후 재시도${NC}"
    exit 1
fi

GPU_NAME=$(python -c "import torch; print(torch.cuda.get_device_name(0))" 2>/dev/null || echo "UNKNOWN")
GPU_MEM=$(python -c "import torch; print(f'{torch.cuda.get_device_properties(0).total_memory/1024**3:.1f}')" 2>/dev/null || echo "0")
echo "  GPU: $GPU_NAME | VRAM: ${GPU_MEM}GB"
echo -e "  CUDA: ${GREEN}OK${NC}"

# weights 확인
echo ""
echo -e "${BLUE}[STEP 0b] Weights 체크...${NC}"
WEIGHTS_MISSING=0
for W in "weights/ProPainter.pth" "weights/recurrent_flow_completion.pth" "weights/raft-things.pth"; do
    if [ -f "$W" ]; then
        SIZE=$(du -sh "$W" | cut -f1)
        echo -e "  ${GREEN}OK${NC} $W ($SIZE)"
    else
        echo -e "  ${YELLOW}MISSING${NC} $W → 첫 실행 시 자동 다운로드 시도됨"
        WEIGHTS_MISSING=$((WEIGHTS_MISSING + 1))
    fi
done
if [ $WEIGHTS_MISSING -gt 0 ]; then
    echo -e "${YELLOW}  [INFO] $WEIGHTS_MISSING 개 weights 파일 없음. 자동 다운로드 시도됩니다.${NC}"
    echo -e "${YELLOW}  실패 시: https://github.com/sczhou/ProPainter/releases/tag/v0.1.0 에서 수동 다운로드${NC}"
fi

echo ""

# ─── STEP 1: 입력 확인 및 실행 명령 구성 ────────────────────────────────────
if [ "$PHASE" = "0" ]; then
    # Phase 0: 공식 샘플 입력
    echo -e "${BLUE}[STEP 1] Phase 0 - 공식 샘플 입력 (running_car.mp4)${NC}"
    VIDEO_INPUT="inputs/video_completion/running_car.mp4"
    MASK_INPUT="inputs/video_completion/mask_square.png"

    if [ ! -f "$VIDEO_INPUT" ]; then
        echo -e "${RED}  [FAIL] 공식 샘플 없음: $VIDEO_INPUT${NC}"
        echo -e "${RED}  → ProPainter 저장소 루트에서 실행하는지 확인${NC}"
        echo -e "${RED}  → git clone https://github.com/sczhou/ProPainter.git 후 재시도${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}OK${NC} 입력 비디오: $VIDEO_INPUT"
    echo -e "  ${GREEN}OK${NC} 마스크: $MASK_INPUT"

elif [ "$PHASE" = "1a" ]; then
    # Phase 1a: 사용자 MP4 + 단일 마스크 PNG
    echo -e "${BLUE}[STEP 1] Phase 1a - 사용자 7초 테스트 (MP4 + 단일 마스크)${NC}"
    VIDEO_INPUT="inputs_user/test_7s_single/your_7s_video.mp4"
    MASK_INPUT="inputs_user/test_7s_single/mask_subtitle.png"

    if [ ! -f "$VIDEO_INPUT" ]; then
        echo -e "${RED}  [FAIL] 사용자 영상 없음: $VIDEO_INPUT${NC}"
        echo -e "${RED}  → 7초 MP4를 inputs_user/test_7s_single/your_7s_video.mp4 로 배치${NC}"
        exit 1
    fi
    if [ ! -f "$MASK_INPUT" ]; then
        echo -e "${YELLOW}  [INFO] 마스크 없음. 자동 생성 시도...${NC}"
        mkdir -p inputs_user/test_7s_single
        python -c "
from PIL import Image, ImageDraw
import os
W, H = 432, 240
mask = Image.new('L', (W, H), 0)
draw = ImageDraw.Draw(mask)
draw.rectangle([0, 190, 432, 240], fill=255)
mask.save('inputs_user/test_7s_single/mask_subtitle.png')
print('마스크 자동 생성: inputs_user/test_7s_single/mask_subtitle.png')
"
    fi
    echo -e "  ${GREEN}OK${NC} 입력 비디오: $VIDEO_INPUT"
    echo -e "  ${GREEN}OK${NC} 마스크: $MASK_INPUT"

elif [ "$PHASE" = "1b" ]; then
    # Phase 1b: 사용자 프레임 폴더 + 마스크 폴더
    echo -e "${BLUE}[STEP 1] Phase 1b - 사용자 7초 테스트 (프레임 폴더 + 마스크 폴더)${NC}"
    VIDEO_INPUT="inputs_user/test_7s/frames"
    MASK_INPUT="inputs_user/test_7s/masks"

    if [ ! -d "$VIDEO_INPUT" ]; then
        echo -e "${RED}  [FAIL] 프레임 폴더 없음: $VIDEO_INPUT${NC}"
        echo -e "${RED}  → input_folder_spec.md 참조하여 프레임 시퀀스 준비${NC}"
        exit 1
    fi

    FRAME_COUNT=$(ls "$VIDEO_INPUT"/*.jpg 2>/dev/null | wc -l)
    MASK_COUNT=$(ls "$MASK_INPUT"/*.png 2>/dev/null | wc -l)
    echo "  프레임 수: $FRAME_COUNT | 마스크 수: $MASK_COUNT"

    if [ "$FRAME_COUNT" != "$MASK_COUNT" ]; then
        echo -e "${RED}  [FAIL] 프레임($FRAME_COUNT)과 마스크($MASK_COUNT) 수 불일치${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}OK${NC} 입력 프레임 폴더: $VIDEO_INPUT"
    echo -e "  ${GREEN}OK${NC} 마스크 폴더: $MASK_INPUT"

else
    echo -e "${RED}  [FAIL] 알 수 없는 Phase: $PHASE (0 / 1a / 1b 중 선택)${NC}"
    echo "  사용법: ./run_smoke_test.sh [0|1a|1b]"
    exit 1
fi

# ─── STEP 2: 실행 명령 출력 및 실행 ─────────────────────────────────────────
echo ""
echo -e "${BLUE}[STEP 2] ProPainter 실행${NC}"
echo ""
echo -e "${YELLOW}  파라미터 (parameter_lock.json 기준):${NC}"
echo "    --width          $WIDTH"
echo "    --height         $HEIGHT"
echo "    --fp16           true"
echo "    --subvideo_length $SUBVIDEO_LENGTH"
echo "    --neighbor_length $NEIGHBOR_LENGTH"
echo "    --ref_stride     $REF_STRIDE"
echo ""

CMD="python inference_propainter.py \
  --video $VIDEO_INPUT \
  --mask $MASK_INPUT \
  --height $HEIGHT \
  --width $WIDTH \
  $FP16 \
  --subvideo_length $SUBVIDEO_LENGTH \
  --neighbor_length $NEIGHBOR_LENGTH \
  --ref_stride $REF_STRIDE"

echo -e "${CYAN}  실행 명령:${NC}"
echo "  $CMD"
echo ""
echo -e "${YELLOW}  [시작] $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo "  ─────────────────────────────────────────────"

START_TIME=$(date +%s)

# 실제 실행
eval $CMD

EXIT_CODE=$?
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo "  ─────────────────────────────────────────────"
echo -e "${YELLOW}  [종료] $(date '+%Y-%m-%d %H:%M:%S') | 소요: ${ELAPSED}초${NC}"
echo ""

# ─── STEP 3: 결과 확인 ───────────────────────────────────────────────────────
echo -e "${BLUE}[STEP 3] 결과 확인${NC}"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}  [PASS] ProPainter 정상 종료 (exit code 0)${NC}"

    # 결과 파일 탐색
    RESULT_DIR="results"
    if [ -d "$RESULT_DIR" ]; then
        echo "  결과 폴더 내용:"
        ls -la "$RESULT_DIR"/ 2>/dev/null || echo "  (비어있음)"

        # mp4 파일 찾기
        MP4_FILES=$(find "$RESULT_DIR" -name "*.mp4" 2>/dev/null)
        if [ -n "$MP4_FILES" ]; then
            echo ""
            echo -e "${GREEN}  [SUCCESS] 결과 영상 생성 확인:${NC}"
            echo "$MP4_FILES" | while read f; do
                SIZE=$(du -sh "$f" | cut -f1)
                echo "    $f ($SIZE)"
            done
        else
            echo -e "${YELLOW}  [WARN] MP4 출력 파일 없음 (프레임 이미지만 존재할 수 있음)${NC}"
            find "$RESULT_DIR" -name "*.jpg" -o -name "*.png" 2>/dev/null | head -5
        fi
    else
        echo -e "${YELLOW}  [WARN] results/ 폴더가 없음${NC}"
    fi

    echo ""
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}  SMOKE TEST RESULT: PASS${NC}"
    echo -e "${GREEN}  Phase: $PHASE | 소요 시간: ${ELAPSED}초${NC}"
    echo -e "${GREEN}============================================================${NC}"

else
    echo -e "${RED}  [FAIL] ProPainter 비정상 종료 (exit code $EXIT_CODE)${NC}"
    echo ""
    echo -e "${RED}  오류 분류 가이드:${NC}"
    echo "  ┌─────────────────────────────────────────────────────────┐"
    echo "  │ CUDA error           → CUDA/드라이버 버전 불일치          │"
    echo "  │ CUDA out of memory   → OOM: fallback 파라미터 적용        │"
    echo "  │ ModuleNotFoundError  → pip install -r requirements.txt    │"
    echo "  │ FileNotFoundError    → weights/ 또는 입력 파일 경로 확인   │"
    echo "  │ RuntimeError (sm_61) → PyTorch 1.13.1+cu118으로 다운그레이드│"
    echo "  └─────────────────────────────────────────────────────────┘"
    echo ""
    echo -e "${RED}  Fallback 명령 (더 보수적인 파라미터):${NC}"
    echo "  python inference_propainter.py \\"
    echo "    --video $VIDEO_INPUT \\"
    echo "    --mask $MASK_INPUT \\"
    echo "    --height 180 --width 320 \\"
    echo "    --fp16 \\"
    echo "    --subvideo_length 30 \\"
    echo "    --neighbor_length 3 \\"
    echo "    --ref_stride 20"
    echo ""
    echo -e "${RED}============================================================${NC}"
    echo -e "${RED}  SMOKE TEST RESULT: FAIL (exit code $EXIT_CODE)${NC}"
    echo -e "${RED}============================================================${NC}"
    exit $EXIT_CODE
fi
