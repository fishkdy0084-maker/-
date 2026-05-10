# result_report.md
# 원본 지우개 — Smoke Test 결과 보고서

---

## 실행 환경

| 항목 | 값 |
|---|---|
| GPU | NVIDIA GeForce GTX 1080 8GB (GPU 1) |
| 드라이버 | 31.0.15.2849 (2023-02-02) |
| 내장 GPU | Intel UHD Graphics 770 (GPU 0, 미사용) |
| 엔진 | ProPainter |
| Plan | Plan A (로컬) |

---

## Phase 0: 공식 샘플 Smoke Test

```
실행 일시: ____-__-__ __:__
실행 명령:
  set CUDA_VISIBLE_DEVICES=1
  python inference_propainter.py
    --video inputs/video_completion/running_car.mp4
    --mask inputs/video_completion/mask_square.png
    --height 240 --width 432 --fp16
    --subvideo_length 50 --neighbor_length 5 --ref_stride 15

결과:        [ ] PASS  [ ] FAIL
소요 시간:   ____초
결과 파일:   results/running_car/inpaint_out.mp4  [ ] 생성됨  [ ] 미생성
로그 파일:   logs/phase0.log

GPU VRAM 최대 사용: ____ GB
```

### 오류 기록 (실패 시)

```
오류 메시지:
  ________________________________________________
  ________________________________________________

오류 분류:
  [ ] 설치 문제 (ImportError, ModuleNotFoundError)
  [ ] CUDA/torch 문제 (CUDA error, sm_61)
  [ ] weight 문제 (FileNotFoundError)
  [ ] 입력 포맷 문제 (shape error, assertion)
  [ ] 메모리(OOM) 문제 (CUDA out of memory)

적용한 수정:
  ________________________________________________
```

---

## Phase 1: 사용자 7초 테스트

```
실행 일시: ____-__-__ __:__
입력 영상:  ________________________________________
마스크:     ________________________________________

결과:        [ ] PASS  [ ] FAIL
소요 시간:   ____초
결과 파일:   __________________________________________
로그 파일:   logs/phase1.log

텍스트 제거 품질 (육안):
  [ ] 텍스트 완전 제거
  [ ] 대부분 제거 (미세 잔상)
  [ ] 제거 불완전 (뚜렷한 잔상)
  [ ] 플리커/깜빡임 있음
```

---

## 판정 요약

| 항목 | Phase 0 | Phase 1 |
|---|---|---|
| 설치 | 미실행 | 미실행 |
| GPU 인식 | 미실행 | 미실행 |
| 실행 완료 | 미실행 | 미실행 |
| OOM 없음 | 미실행 | 미실행 |
| 결과 파일 생성 | 미실행 | 미실행 |
| 텍스트 제거 확인 | 미실행 | 미실행 |
| 재실행 가능 | 미실행 | 미실행 |

---

## 비고

- 이 문서는 실행 전 템플릿 상태다.
- 로컬 GTX 1080 PC에서 실행 후 결과를 기입한다.
- 실패 시 원인을 5가지 분류 중 하나로 반드시 기록한다.
- 결과 파일 없이 성공 판정하지 않는다.
- 로그 없이 실패 판정하지 않는다.

---

*원본 지우개 실행개발팀 | 2026-05-10*
