#!/usr/bin/env bash
# =========================================================
# [오버레이형] smoke test 실행 (Linux/Mac)
# 전제: ProPainter 설치 + Quick Test 완료
# =========================================================
#   bash run_smoke_test.sh       → Phase 0
#   bash run_smoke_test.sh 0     → Phase 0
#   bash run_smoke_test.sh 1     → Phase 1

set -e
PHASE="${1:-0}"

# GPU 0=Intel UHD 770, GPU 1=GTX 1080
export CUDA_VISIBLE_DEVICES=1

echo "========================================================="
echo " Smoke Test - Phase $PHASE"
echo " CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
echo "========================================================="
echo ""

# === [1/6] 전제조건 확인 ===
echo "[1/6] 전제조건 확인"

if [ ! -f "inference_propainter.py" ]; then
    echo "[FAIL] inference_propainter.py 없음."
    echo "  이 스크립트는 ProPainter 루트에서 실행해야 합니다."
    exit 1
fi

if command -v conda &>/dev/null; then
    eval "$(conda shell.bash hook)"
    conda activate propainter
fi

python -c "import torch; assert torch.cuda.is_available()" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[FAIL] torch/CUDA 사용 불가"
    exit 1
fi
echo "  ProPainter 루트: OK"
echo "  torch/CUDA: OK"
echo ""

# === [2/6] 폴더 자동 생성 ===
echo "[2/6] 폴더 구조 생성"
mkdir -p logs output results input/video input/masks/test_mask
echo "  OK"
echo ""

# === [3/6] 입력 경로 설정 ===
if [ "$PHASE" = "0" ]; then
    echo "[3/6] Phase 0 - 공식 샘플"
    VIDEO_PATH="inputs/video_completion/running_car.mp4"
    MASK_PATH="inputs/video_completion/mask_square.png"
    OUTPUT_LOG="logs/phase0.log"
    RESULT_FILE="results/running_car/inpaint_out.mp4"

    if [ ! -f "$VIDEO_PATH" ]; then
        echo "[FAIL] 공식 샘플 없음: $VIDEO_PATH"
        exit 1
    fi
elif [ "$PHASE" = "1" ]; then
    echo "[3/6] Phase 1 - 7초 테스트"
    VIDEO_PATH="input/video/test_input.mp4"
    MASK_PATH="input/masks/test_mask"
    OUTPUT_LOG="logs/phase1.log"
    RESULT_FILE="results/test_input/inpaint_out.mp4"

    if [ ! -f "$VIDEO_PATH" ]; then
        echo "[FAIL] 테스트 영상 없음: $VIDEO_PATH"
        exit 1
    fi
    if [ -z "$(ls -A $MASK_PATH/*.png 2>/dev/null)" ]; then
        echo "[FAIL] 마스크 없음: $MASK_PATH/*.png"
        exit 1
    fi
else
    echo "[FAIL] 알 수 없는 Phase: $PHASE (0 또는 1)"
    exit 1
fi
echo "  VIDEO: $VIDEO_PATH"
echo "  MASK:  $MASK_PATH"
echo ""

# === [4/6] 실행 ===
echo "[4/6] ProPainter 실행"
echo "  파라미터: 432x240 fp16 subvideo=50 neighbor=5 ref_stride=15"
echo "  로그: $OUTPUT_LOG"
echo ""

set +e
python inference_propainter.py \
  --video "$VIDEO_PATH" \
  --mask "$MASK_PATH" \
  --height 240 \
  --width 432 \
  --fp16 \
  --subvideo_length 50 \
  --neighbor_length 5 \
  --ref_stride 15 > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

# === [5/6] 결과 확인 ===
echo "[5/6] 결과 확인"

if [ $EXIT_CODE -eq 0 ]; then
    if [ -f "$RESULT_FILE" ]; then
        echo "  [PASS] exit 0, 결과 파일 생성됨"
        echo "  결과: $RESULT_FILE"
    else
        echo "  [WARN] exit 0이지만 결과 파일 없음: $RESULT_FILE"
    fi
else
    echo "  [FAIL] exit code $EXIT_CODE"
    echo ""
    echo "  로그 마지막 20줄:"
    tail -20 "$OUTPUT_LOG" 2>/dev/null
    echo ""
    echo "  OOM 시 축소 재시도:"
    echo "  python inference_propainter.py --video \"$VIDEO_PATH\" --mask \"$MASK_PATH\" --height 176 --width 320 --fp16 --subvideo_length 30 --neighbor_length 3 --ref_stride 20"
fi
echo ""

# === [6/6] 요약 ===
echo "[6/6] 요약"
echo "  Phase:     $PHASE"
echo "  Exit code: $EXIT_CODE"
echo "  Log:       $OUTPUT_LOG"
echo "  Result:    $RESULT_FILE"

exit $EXIT_CODE
