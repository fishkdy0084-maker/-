#!/usr/bin/env bash
# ============================================================
# run_smoke_test.sh
# 원본 지우개 - ProPainter Smoke Test (Linux/Mac)
# 대상: GTX 1080 8GB / parameter_lock.json 기준
# ============================================================
# 사용법:
#   bash run_smoke_test.sh         → Phase 0 (공식 샘플)
#   bash run_smoke_test.sh 0       → Phase 0 (공식 샘플)
#   bash run_smoke_test.sh 1       → Phase 1 (사용자 7초 테스트)
# ============================================================

set -e

PHASE="${1:-0}"

# --- GPU 선택 (GPU 0 = Intel UHD, GPU 1 = GTX 1080) ---
export CUDA_VISIBLE_DEVICES=1

# --- 파라미터 고정값 ---
WIDTH=432
HEIGHT=240
SUBVIDEO_LENGTH=50
NEIGHBOR_LENGTH=5
REF_STRIDE=15

echo "============================================================"
echo "  원본 지우개 - ProPainter Smoke Test"
echo "  GPU: GTX 1080 8GB (CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES)"
echo "  Phase: $PHASE"
echo "============================================================"
echo ""

# === STEP 0: 환경 체크 ===
echo "[STEP 0] 환경 체크"
python --version
python -c "import torch; print('torch:', torch.__version__); print('CUDA:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'NONE')"
echo ""

# === STEP 0b: Weights 체크 ===
echo "[STEP 0b] Weights 체크"
for W in weights/ProPainter.pth weights/recurrent_flow_completion.pth weights/raft-things.pth; do
    if [ -f "$W" ]; then echo "  OK $W"; else echo "  MISSING $W"; fi
done
echo ""

# === STEP 1: 입력 구성 ===
if [ "$PHASE" = "0" ]; then
    echo "[STEP 1] Phase 0 - 공식 샘플"
    VIDEO_INPUT="inputs/video_completion/running_car.mp4"
    MASK_INPUT="inputs/video_completion/mask_square.png"
    LOG_FILE="logs/phase0.log"

    if [ ! -f "$VIDEO_INPUT" ]; then
        echo "[FAIL] 공식 샘플 없음. ProPainter 루트에서 실행 확인."
        exit 1
    fi

elif [ "$PHASE" = "1" ]; then
    echo "[STEP 1] Phase 1 - 사용자 7초 테스트"
    VIDEO_INPUT="input/video/test_input.mp4"
    MASK_INPUT="input/masks/test_mask.png"
    LOG_FILE="logs/phase1.log"

    if [ ! -f "$VIDEO_INPUT" ]; then
        echo "[FAIL] 사용자 영상 없음: $VIDEO_INPUT"
        exit 1
    fi
    if [ ! -f "$MASK_INPUT" ]; then
        if [ -d "input/masks/test_mask" ]; then
            MASK_INPUT="input/masks/test_mask"
        else
            echo "[FAIL] 마스크 없음. input_folder_spec.md 참조"
            exit 1
        fi
    fi

else
    echo "[FAIL] 알 수 없는 Phase: $PHASE (0 또는 1)"
    exit 1
fi

echo "  영상: $VIDEO_INPUT"
echo "  마스크: $MASK_INPUT"
echo ""

# === STEP 2: 실행 ===
mkdir -p logs

echo "[STEP 2] ProPainter 실행"
echo ""
echo "  고정 파라미터:"
echo "    --width           $WIDTH"
echo "    --height          $HEIGHT"
echo "    --fp16"
echo "    --subvideo_length $SUBVIDEO_LENGTH"
echo "    --neighbor_length $NEIGHBOR_LENGTH"
echo "    --ref_stride      $REF_STRIDE"
echo ""

CMD="python inference_propainter.py --video $VIDEO_INPUT --mask $MASK_INPUT --height $HEIGHT --width $WIDTH --fp16 --subvideo_length $SUBVIDEO_LENGTH --neighbor_length $NEIGHBOR_LENGTH --ref_stride $REF_STRIDE"

echo "  명령: $CMD"
echo ""
echo "[시작] $(date '+%Y-%m-%d %H:%M:%S')"
echo "─────────────────────────────────────"

START_TIME=$(date +%s)
set +e
eval $CMD 2>&1 | tee "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
set -e

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo "─────────────────────────────────────"
echo "[종료] $(date '+%Y-%m-%d %H:%M:%S') | 소요: ${ELAPSED}초"
echo ""

# === STEP 3: 결과 확인 ===
echo "[STEP 3] 결과 확인"

if [ $EXIT_CODE -eq 0 ]; then
    echo "  [PASS] 정상 종료"
    find results -name "*.mp4" 2>/dev/null && echo "" || echo "  MP4 없음"
    echo ""
    echo "============================================================"
    echo "  SMOKE TEST: PASS (Phase $PHASE, ${ELAPSED}초)"
    echo "  로그: $LOG_FILE"
    echo "============================================================"
else
    echo "  [FAIL] 비정상 종료 (exit code $EXIT_CODE)"
    echo ""
    echo "  Fallback 명령:"
    echo "  python inference_propainter.py \\"
    echo "    --video $VIDEO_INPUT --mask $MASK_INPUT \\"
    echo "    --height 176 --width 320 --fp16 \\"
    echo "    --subvideo_length 30 --neighbor_length 3 --ref_stride 20"
    echo ""
    echo "============================================================"
    echo "  SMOKE TEST: FAIL (Phase $PHASE, exit code $EXIT_CODE)"
    echo "  로그: $LOG_FILE"
    echo "============================================================"
    exit $EXIT_CODE
fi
