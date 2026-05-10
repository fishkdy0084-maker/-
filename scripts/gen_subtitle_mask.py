#!/usr/bin/env python3
"""
gen_subtitle_mask.py
프로젝트: 원본 지우개
목적: 고정 자막 영역에 대한 ProPainter용 마스크 시퀀스 생성
버전: v1.0 | 기준일: 2026-05-10

사용법:
  python scripts/gen_subtitle_mask.py

출력:
  inputs_user/test_7s/masks/00000.png ~ 0000N.png
  (흰색=255=제거 영역, 검정=0=보존 영역)
"""

import os
import sys
import numpy as np
from PIL import Image, ImageDraw


# ============================================================
# 사용자 설정 영역 (실행 전 수정)
# ============================================================

# 출력 프레임 해상도 (parameter_lock.json 기준)
FRAME_W = 432
FRAME_H = 240

# 총 프레임 수 계산: 영상 길이(초) × FPS
VIDEO_DURATION_SEC = 7
VIDEO_FPS = 24   # 실제 FPS에 맞게 수정
FRAME_COUNT = VIDEO_DURATION_SEC * VIDEO_FPS  # 기본 168

# 출력 폴더
OUTPUT_DIR = "inputs_user/test_7s/masks"

# 자막 영역 정의 (리사이즈된 432x240 기준 픽셀 좌표)
# 형식: (x1, y1, x2, y2)  ← 좌상단(x1,y1), 우하단(x2,y2)
# 여러 영역 정의 가능 (리스트에 추가)
#
# 예시 가이드:
#   - 하단 자막 (일반적 중국 드라마 자막 위치):
#     하단 15~20% 영역 → y1 ≈ 192, y2 = 240
#   - 상단 자막 (번역 자막이 상단에 있을 경우):
#     y1 ≈ 0, y2 ≈ 48
#   - 말풍선 (위치가 고정된 경우):
#     해당 좌표 측정 후 입력
SUBTITLE_REGIONS = [
    # 하단 자막 영역 (432x240 기준, 하단 50px)
    (0, 190, 432, 240),
    # 필요 시 추가 영역:
    # (50, 10, 382, 50),    # 상단 자막
    # (100, 120, 330, 170), # 말풍선 중앙
]

# 마스크 팽창 (Dilation) 픽셀 수
# 자막 경계를 조금 더 넉넉하게 마스킹하려면 양수로 설정
# 0 = 정확한 영역만, 5 = 5px 외부로 확장
MASK_DILATION_PX = 3

# ============================================================


def create_mask_for_regions(width, height, regions, dilation_px=0):
    """지정된 영역을 흰색(255)으로 채운 grayscale 마스크 생성"""
    mask = np.zeros((height, width), dtype=np.uint8)

    for (x1, y1, x2, y2) in regions:
        # 팽창 적용
        x1d = max(0, x1 - dilation_px)
        y1d = max(0, y1 - dilation_px)
        x2d = min(width, x2 + dilation_px)
        y2d = min(height, y2 + dilation_px)
        mask[y1d:y2d, x1d:x2d] = 255

    return mask


def validate_regions(regions, width, height):
    """영역 좌표 유효성 검사"""
    for i, (x1, y1, x2, y2) in enumerate(regions):
        if x1 >= x2 or y1 >= y2:
            print(f"  [ERROR] Region {i}: x1({x1}) >= x2({x2}) 또는 y1({y1}) >= y2({y2})")
            return False
        if x1 < 0 or y1 < 0 or x2 > width or y2 > height:
            print(f"  [WARN] Region {i}: 좌표가 해상도 범위 초과 → 자동 클리핑됨")
    return True


def main():
    print("=" * 60)
    print("  gen_subtitle_mask.py - 자막 마스크 생성기")
    print("=" * 60)
    print(f"  해상도: {FRAME_W} x {FRAME_H}")
    print(f"  프레임 수: {FRAME_COUNT} ({VIDEO_DURATION_SEC}초 x {VIDEO_FPS}fps)")
    print(f"  자막 영역: {len(SUBTITLE_REGIONS)}개")
    print(f"  마스크 팽창: {MASK_DILATION_PX}px")
    print(f"  출력 폴더: {OUTPUT_DIR}")
    print()

    # 유효성 검사
    if not validate_regions(SUBTITLE_REGIONS, FRAME_W, FRAME_H):
        print("[ERROR] 영역 설정 오류. SUBTITLE_REGIONS 확인 후 재실행.")
        sys.exit(1)

    # 출력 폴더 생성
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 마스크 생성 (모든 프레임 동일)
    mask_array = create_mask_for_regions(
        FRAME_W, FRAME_H, SUBTITLE_REGIONS, MASK_DILATION_PX
    )

    white_pixels = np.sum(mask_array > 0)
    total_pixels = FRAME_W * FRAME_H
    coverage_pct = white_pixels / total_pixels * 100
    print(f"  마스크 커버리지: {white_pixels}px ({coverage_pct:.1f}%)")
    print()

    # 프레임별 마스크 저장
    mask_img = Image.fromarray(mask_array, mode='L')

    for i in range(FRAME_COUNT):
        output_path = os.path.join(OUTPUT_DIR, f"{i:05d}.png")
        mask_img.save(output_path)
        if i % 50 == 0:
            print(f"  진행: {i+1}/{FRAME_COUNT} ({(i+1)/FRAME_COUNT*100:.0f}%)")

    print()
    print(f"  [완료] {FRAME_COUNT}개 마스크 생성 → {OUTPUT_DIR}/")
    print()

    # 검증
    first_mask_path = os.path.join(OUTPUT_DIR, "00000.png")
    check = Image.open(first_mask_path)
    arr = np.array(check)
    unique_vals = np.unique(arr)
    print(f"  [검증] 첫 번째 마스크: {first_mask_path}")
    print(f"    Mode: {check.mode}")
    print(f"    Size: {check.size}")
    print(f"    고유값: {unique_vals}")
    print()

    # 단일 마스크 모드용 복사 (--mask 옵션에 단일 파일 사용 시)
    single_mask_dir = "inputs_user/test_7s_single"
    os.makedirs(single_mask_dir, exist_ok=True)
    single_mask_path = os.path.join(single_mask_dir, "mask_subtitle.png")
    mask_img.save(single_mask_path)
    print(f"  [추가] 단일 마스크 복사: {single_mask_path}")
    print("    → --mask inputs_user/test_7s_single/mask_subtitle.png 으로 사용 가능")
    print()

    print("=" * 60)
    print("  다음 실행 명령:")
    print()
    print("  # 프레임 폴더 + 마스크 폴더 모드:")
    print("  python inference_propainter.py \\")
    print("    --video inputs_user/test_7s/frames \\")
    print("    --mask inputs_user/test_7s/masks \\")
    print("    --height 240 --width 432 --fp16 \\")
    print("    --subvideo_length 50 --neighbor_length 5 --ref_stride 15")
    print()
    print("  # 단일 마스크 모드:")
    print("  python inference_propainter.py \\")
    print("    --video inputs_user/test_7s_single/your_7s_video.mp4 \\")
    print("    --mask inputs_user/test_7s_single/mask_subtitle.png \\")
    print("    --height 240 --width 432 --fp16 \\")
    print("    --subvideo_length 50 --neighbor_length 5 --ref_stride 15")
    print("=" * 60)


if __name__ == "__main__":
    main()
