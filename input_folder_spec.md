# input_folder_spec.md
# 원본 지우개 — 입력/출력 폴더 구조

---

## 실제 테스트 영상 정보

| 항목 | 값 |
|---|---|
| 원본 파일 | 7초.mp4 |
| 코덱 | H.265 → H.264 변환 |
| 해상도 | 480 x 854 (세로) |
| FPS | 24 |
| 프레임 수 | 168 |
| 길이 | 7.0초 |
| 오디오 | AAC 44100Hz stereo |
| 내용 | 애니메이션, 말풍선 형태 중국어 텍스트 |
| 텍스트 위치 | 프레임마다 변동 (말풍선) |
| 마스크 방식 | 프레임별 OCR 마스크 (168장) |

---

## 폴더 구조

```
ProPainter/
├── inference_propainter.py
├── weights/
│   ├── ProPainter.pth
│   ├── recurrent_flow_completion.pth
│   └── raft-things.pth
├── inputs/                              ← 공식 샘플 (Phase 0)
│   └── video_completion/
│       ├── running_car.mp4
│       └── mask_square.png
├── input/                               ← 사용자 입력 (Phase 1)
│   ├── video/
│   │   └── test_input.mp4              ← H.264 변환된 7초 영상
│   └── masks/
│       └── test_mask/                   ← OCR 기반 프레임별 마스크
│           ├── 00001.png
│           ├── 00002.png
│           ├── ...
│           └── 00168.png
├── results/                             ← ProPainter 출력
│   ├── running_car/                     ← Phase 0 결과
│   │   ├── masked_in.mp4
│   │   └── inpaint_out.mp4
│   └── test_input/                      ← Phase 1 결과
│       ├── masked_in.mp4
│       └── inpaint_out.mp4
├── logs/
│   ├── phase0.log
│   └── phase1.log
├── config/
│   └── parameter_lock.json
└── scripts/
    ├── run_smoke_test.bat
    ├── run_smoke_test.sh
    └── gen_masks.py
```

---

## 마스크 규칙

- 포맷: PNG, 흑백(L 모드)
- 흰색(255) = 제거 영역, 검정(0) = 보존
- 해상도: 480x854 (원본과 동일. ProPainter가 432x240으로 자동 리사이즈)
- 파일명: `00001.png` ~ `00168.png` (5자리 zero-padding, 1-indexed)
- 168장 = 168프레임과 1:1 매칭
- OCR(EasyOCR) 기반 자동 생성, 패딩 15px

---

## Phase별 입력

### Phase 0 — 공식 샘플

```
--video inputs/video_completion/running_car.mp4
--mask  inputs/video_completion/mask_square.png
```

### Phase 1 — 7초 테스트

```
--video input/video/test_input.mp4
--mask  input/masks/test_mask
```

ProPainter는 `--mask`가 폴더면 프레임별 마스크, 파일이면 단일 마스크로 인식한다.

---

*원본 지우개 실행개발팀 | 2026-05-10*
