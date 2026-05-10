#!/usr/bin/env bash
# =============================================================================
# extract_frames.sh
# 프로젝트: 원본 지우개
# 목적: 원본 MP4에서 7초 구간 추출 + 프레임 시퀀스 변환
# 버전: v1.0 | 기준일: 2026-05-10
# =============================================================================
# 사용법:
#   bash scripts/extract_frames.sh <입력MP4> [시작초] [종료초]
#
# 예시:
#   bash scripts/extract_frames.sh original.mp4          # 처음 7초
#   bash scripts/extract_frames.sh original.mp4 30 37    # 30초~37초 구간
# =============================================================================

INPUT_VIDEO="${1:-}"
START_SEC="${2:-0}"
END_SEC="${3:-7}"
DURATION=$((END_SEC - START_SEC))

OUTPUT_VIDEO="inputs_user/test_7s_single/your_7s_video.mp4"
OUTPUT_FRAMES="inputs_user/test_7s/frames"

# 입력 확인
if [ -z "$INPUT_VIDEO" ]; then
    echo "[ERROR] 입력 MP4 파일을 지정하세요."
    echo "사용법: bash scripts/extract_frames.sh <입력MP4> [시작초] [종료초]"
    exit 1
fi

if [ ! -f "$INPUT_VIDEO" ]; then
    echo "[ERROR] 파일 없음: $INPUT_VIDEO"
    exit 1
fi

echo "============================================================"
echo "  extract_frames.sh - 프레임 추출기"
echo "  입력: $INPUT_VIDEO"
echo "  구간: ${START_SEC}초 ~ ${END_SEC}초 (${DURATION}초)"
echo "============================================================"
echo ""

# ffmpeg 확인
if ! command -v ffmpeg &> /dev/null; then
    echo "[INFO] ffmpeg 없음. Python imageio-ffmpeg 사용 시도..."
    FFMPEG_BIN=$(python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())" 2>/dev/null)
    if [ -z "$FFMPEG_BIN" ]; then
        echo "[ERROR] ffmpeg를 찾을 수 없음."
        echo "  설치: conda install ffmpeg -c conda-forge"
        echo "  또는: pip install imageio-ffmpeg"
        exit 1
    fi
    echo "[INFO] ffmpeg 경로: $FFMPEG_BIN"
else
    FFMPEG_BIN="ffmpeg"
fi

# 출력 폴더 생성
mkdir -p "$(dirname "$OUTPUT_VIDEO")"
mkdir -p "$OUTPUT_FRAMES"

# STEP 1: 7초 MP4 추출 (432x240 리사이즈)
echo "[STEP 1] 7초 구간 MP4 추출 및 432x240 리사이즈..."
"$FFMPEG_BIN" -y \
    -i "$INPUT_VIDEO" \
    -ss "$START_SEC" -t "$DURATION" \
    -vf "scale=432:240" \
    -c:v libx264 -preset fast -crf 18 \
    -c:a aac -b:a 128k \
    "$OUTPUT_VIDEO" 2>&1 | tail -5

if [ $? -eq 0 ]; then
    echo "  [OK] MP4 추출 완료: $OUTPUT_VIDEO"
else
    echo "  [FAIL] MP4 추출 실패"
    exit 1
fi

# STEP 2: 프레임 시퀀스 추출
echo ""
echo "[STEP 2] 프레임 시퀀스 추출 → $OUTPUT_FRAMES/"
"$FFMPEG_BIN" -y \
    -i "$OUTPUT_VIDEO" \
    -q:v 2 \
    "$OUTPUT_FRAMES/%05d.jpg" 2>&1 | tail -3

if [ $? -eq 0 ]; then
    FRAME_COUNT=$(ls "$OUTPUT_FRAMES"/*.jpg 2>/dev/null | wc -l)
    echo "  [OK] 프레임 추출 완료: ${FRAME_COUNT}장 → $OUTPUT_FRAMES/"
else
    echo "  [FAIL] 프레임 추출 실패"
    exit 1
fi

echo ""
echo "============================================================"
echo "  완료 요약:"
echo "  - 7초 MP4:  $OUTPUT_VIDEO"
echo "  - 프레임:   $OUTPUT_FRAMES/ (${FRAME_COUNT}장)"
echo ""
echo "  다음 단계:"
echo "  1. python scripts/gen_subtitle_mask.py  # 마스크 생성"
echo "  2. bash scripts/run_smoke_test.sh 1a    # 단일 마스크 모드 실행"
echo "     또는"
echo "  2. bash scripts/run_smoke_test.sh 1b    # 프레임 폴더 모드 실행"
echo "============================================================"
