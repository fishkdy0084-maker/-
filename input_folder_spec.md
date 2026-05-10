# input_folder_spec.md
# 원본 지우개 — 입력/출력 폴더 구조 및 파일명 규칙

---

## 루트 폴더 구조

```
ProPainter/                          ← ProPainter 저장소 루트
├── inference_propainter.py          ← 실행 스크립트
├── weights/                         ← 모델 weights
│   ├── ProPainter.pth
│   ├── recurrent_flow_completion.pth
│   └── raft-things.pth
├── inputs/                          ← 공식 샘플 (Phase 0)
│   └── video_completion/
│       ├── running_car.mp4
│       ├── mask_square.png
│       └── mask_logo.png
├── input/                           ← 사용자 테스트 입력 (Phase 1~)
│   ├── video/
│   │   └── test_input.mp4
│   └── masks/
│       └── test_mask/
│           ├── 00000.png
│           ├── 00001.png
│           └── ...
├── output/                          ← 실행 결과
│   └── run_001/
├── logs/                            ← 실행 로그
│   └── run_001.log
├── config/                          ← 설정 파일
│   └── parameter_lock.json
├── scripts/                         ← 실행 스크립트
│   └── run_smoke_test.bat
└── results/                         ← ProPainter 기본 출력 경로
    └── running_car/
        ├── masked_in.mp4
        └── inpaint_out.mp4
```

---

## Phase별 입력 경로

### Phase 0 — 공식 샘플 (설치 검증)

| 항목 | 경로 |
|---|---|
| 영상 | `inputs/video_completion/running_car.mp4` |
| 마스크 | `inputs/video_completion/mask_square.png` (단일 PNG) |
| 출력 | `results/running_car/` |

ProPainter는 마스크가 단일 PNG이면 모든 프레임에 동일 마스크를 적용한다.

### Phase 1 — 사용자 7초 테스트

| 항목 | 경로 |
|---|---|
| 영상 | `input/video/test_input.mp4` |
| 마스크 (단일) | `input/masks/test_mask.png` |
| 마스크 (시퀀스) | `input/masks/test_mask/00000.png` ~ |
| 출력 | `output/run_001/` |

---

## 파일명 규칙

| 항목 | 규칙 |
|---|---|
| 영상 | `test_input.mp4` (MP4) |
| 마스크 폴더 | `test_mask` |
| 마스크 파일 | `00000.png` 5자리 zero-padding |
| 출력 폴더 | `run_001`, `run_002` ... |
| 로그 | `run_001.log` |
| 파라미터 | `parameter_lock.json` |

---

## 마스크 규칙

1. 포맷: PNG
2. 모드: 흑백 (L 모드 또는 RGB에서 변환)
3. 흰색(255) = 제거할 영역
4. 검정(0) = 보존할 영역
5. 해상도: 영상과 동일 (리사이즈는 ProPainter가 자동 처리)
6. 단일 마스크: 모든 프레임에 동일 적용
7. 시퀀스 마스크: 프레임 수와 1:1 매칭 필수

---

## 첫 실행 원칙

1. Phase 0: 공식 샘플 `running_car.mp4` + `mask_square.png`
2. Phase 1: 사용자 `test_input.mp4` + 단일 마스크 `test_mask.png`
3. Phase 2: 시퀀스 마스크로 확장
4. 품질보다 실행 가능 상태 확보를 우선

---

## ProPainter 출력 구조 (코드에서 확인)

```python
# inference_propainter.py 471-472행
imageio.mimwrite(os.path.join(save_root, 'masked_in.mp4'), ...)
imageio.mimwrite(os.path.join(save_root, 'inpaint_out.mp4'), ...)
```

| 파일 | 설명 |
|---|---|
| `masked_in.mp4` | 마스크 영역을 녹색으로 표시한 원본 |
| `inpaint_out.mp4` | 인페인팅 완료된 결과 영상 |

`--save_frames` 옵션 추가 시 `frames/0000.png` ~ 프레임 이미지도 저장된다.

---

*원본 지우개 실행개발팀 | 2026-05-10*
