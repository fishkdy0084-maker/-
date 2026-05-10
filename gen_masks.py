#!/usr/bin/env python3
"""
gen_masks.py — OCR 기반 프레임별 마스크 생성
원본 지우개 / 7초 테스트
"""
import os
import numpy as np
from PIL import Image, ImageDraw
import easyocr

FRAME_DIR = "all_frames"
MASK_DIR = "input/masks/test_mask"
W, H = 480, 854  # 원본 해상도
PADDING = 15      # 텍스트 bbox 주변 패딩 (px)

os.makedirs(MASK_DIR, exist_ok=True)

reader = easyocr.Reader(['ch_sim', 'en'], gpu=False, verbose=False)

frames = sorted(os.listdir(FRAME_DIR))
total = len(frames)
print(f"총 {total}프레임 처리 시작")

text_count = 0
for i, fname in enumerate(frames):
    fpath = os.path.join(FRAME_DIR, fname)
    
    # OCR 실행
    results = reader.readtext(fpath, paragraph=False)
    
    # 마스크 생성 (검정 배경)
    mask = Image.new('L', (W, H), 0)
    draw = ImageDraw.Draw(mask)
    
    for bbox, text, conf in results:
        if conf < 0.05:  # 매우 낮은 확신도 제외
            continue
        # bbox: [[x1,y1],[x2,y1],[x2,y2],[x1,y2]]
        xs = [p[0] for p in bbox]
        ys = [p[1] for p in bbox]
        x1 = max(0, int(min(xs)) - PADDING)
        y1 = max(0, int(min(ys)) - PADDING)
        x2 = min(W, int(max(xs)) + PADDING)
        y2 = min(H, int(max(ys)) + PADDING)
        draw.rectangle([x1, y1, x2, y2], fill=255)
        text_count += 1
    
    # 5자리 zero-padding (00001.png ~ )
    # ProPainter는 sorted 순서로 읽으므로 ffmpeg 출력과 동일하게 1-indexed
    idx = int(fname.split('.')[0])
    mask_path = os.path.join(MASK_DIR, f"{idx:05d}.png")
    mask.save(mask_path)
    
    if (i + 1) % 20 == 0 or i == 0 or i == total - 1:
        print(f"  [{i+1}/{total}] {fname} → {len(results)} texts detected")

print(f"\n완료: {total}개 마스크 → {MASK_DIR}/")
print(f"총 텍스트 영역: {text_count}개")

# 검증
mask_files = sorted(os.listdir(MASK_DIR))
print(f"마스크 파일 수: {len(mask_files)}")
print(f"첫 번째: {mask_files[0]}, 마지막: {mask_files[-1]}")

# 마스크 커버리지 통계
white_counts = []
for mf in mask_files:
    m = np.array(Image.open(os.path.join(MASK_DIR, mf)))
    white_counts.append(np.sum(m > 0))

nonzero = sum(1 for c in white_counts if c > 0)
print(f"텍스트가 있는 프레임: {nonzero}/{total}")
if white_counts:
    avg_coverage = np.mean([c for c in white_counts if c > 0]) / (W * H) * 100 if nonzero > 0 else 0
    print(f"평균 마스크 커버리지 (텍스트 프레임): {avg_coverage:.1f}%")
