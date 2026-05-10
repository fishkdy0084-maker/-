# result_report.md
# 원본 지우개 — Smoke Test 결과 보고서

---

## 실행 환경

| 항목 | 값 |
|---|---|
| GPU | NVIDIA GeForce GTX 1080 8GB (GPU 1) |
| 드라이버 | 31.0.15.2849 (2023-02-02) |
| 내장 GPU | Intel UHD Graphics 770 (GPU 0, CUDA_VISIBLE_DEVICES=1) |
| 엔진 | ProPainter |
| Plan | Plan A (로컬) |

---

## Phase 0: 공식 샘플

```
실행 일시:  ____-__-__ __:__
명령:
  set CUDA_VISIBLE_DEVICES=1
  python inference_propainter.py
    --video inputs/video_completion/running_car.mp4
    --mask inputs/video_completion/mask_square.png
    --height 240 --width 432 --fp16
    --subvideo_length 50 --neighbor_length 5 --ref_stride 15

결과:        [ ] PASS  [ ] FAIL
소요 시간:   ____초
결과 파일:   results/running_car/inpaint_out.mp4  [ ] 생성  [ ] 미생성
로그 파일:   logs/phase0.log
VRAM 최대:   ____ GB
```

### 오류 기록 (실패 시)
```
오류 메시지:  ________________________________________________
오류 분류:
  [ ] 설치 문제    [ ] CUDA/torch 문제    [ ] weight 문제
  [ ] 입력 포맷 문제    [ ] OOM 문제
수정 내용:    ________________________________________________
```

---

## Phase 1: 7초 테스트 (실제 영상)

```
실행 일시:  ____-__-__ __:__
입력 영상:  input/video/test_input.mp4 (480x854, H.264, 168프레임)
마스크:     input/masks/test_mask/ (OCR 기반 168장)
명령:
  set CUDA_VISIBLE_DEVICES=1
  python inference_propainter.py
    --video input/video/test_input.mp4
    --mask input/masks/test_mask
    --height 240 --width 432 --fp16
    --subvideo_length 50 --neighbor_length 5 --ref_stride 15

결과:        [ ] PASS  [ ] FAIL
소요 시간:   ____초
결과 파일:   results/test_input/inpaint_out.mp4  [ ] 생성  [ ] 미생성
로그 파일:   logs/phase1.log
VRAM 최대:   ____ GB

텍스트 제거 품질 (육안):
  [ ] 완전 제거
  [ ] 대부분 제거 (미세 잔상)
  [ ] 불완전 (뚜렷한 잔상)
  [ ] 플리커/깜빡임
```

---

## 판정 요약

| 항목 | Phase 0 | Phase 1 |
|---|---|---|
| 설치 | 미실행 | 미실행 |
| GPU 인식 | 미실행 | 미실행 |
| 실행 완료 | 미실행 | 미실행 |
| OOM 없음 | 미실행 | 미실행 |
| 결과 파일 | 미실행 | 미실행 |
| 텍스트 제거 | 미실행 | 미실행 |

---

*원본 지우개 실행개발팀 | 2026-05-10*
