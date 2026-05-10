# result_report.md
# ProPainter Smoke Test 결과 보고서 (템플릿 + 사전 분석)
# 프로젝트: 원본 지우개 | 버전: v1.0 | 기준일: 2026-05-10

---

## 1. 실행 환경 요약

| 항목 | 값 |
|---|---|
| 프로젝트명 | 원본 지우개 |
| 실행 목표 | GTX 1080 8GB에서 7초 영상 자막 제거 1회 성공 |
| 도구 | ProPainter (sczhou/ProPainter) |
| GPU | NVIDIA GeForce GTX 1080 8.0 GB |
| 드라이버 | 31.0.15.2849 (2023-02-02) |
| 파라미터 기준 | parameter_lock.json v1.0 |
| 실행 스크립트 | scripts/run_smoke_test.sh (Linux/Mac) / run_smoke_test.bat (Windows) |

---

## 2. 사전 VRAM 예측 (실행 전 이론값)

공식 ProPainter 문서 기준:

| 해상도 | subvideo_length | fp16 | 예상 VRAM | GTX 1080 8GB 가능 여부 |
|---|---|---|---|---|
| 432 × 240 | 50 | ✅ | ~3~4 GB | **✅ 안전** |
| 432 × 240 | 50 | ❌ (fp32) | ~5~6 GB | ⚠️ 주의 (가능하나 여유 없음) |
| 432 × 240 | 80 | ✅ | ~4~5 GB | ✅ 가능 |
| 720 × 480 | 50 | ✅ | ~7 GB | ⚠️ 아슬 (OOM 가능성 있음) |
| 720 × 480 | 50 | ❌ (fp32) | ~11 GB | ❌ OOM 확실 |
| 1280 × 720 | 50 | ✅ | OOM | ❌ OOM 확실 |

**1차 smoke test 설정: 432×240, fp16, subvideo_length=50 → 예상 VRAM ~3-4 GB → 안전 범위**

---

## 3. Smoke Test 실행 결과 기록 (사용자가 실행 후 기입)

### Phase 0: 공식 샘플 (running_car.mp4)

```
실행 일시: ____-__-__ __:__
실행 명령:
  python inference_propainter.py \
    --video inputs/video_completion/running_car.mp4 \
    --mask inputs/video_completion/mask_square.png \
    --height 240 --width 432 --fp16 \
    --subvideo_length 50 --neighbor_length 5 --ref_stride 15

─────────────────────────────────────────────
실행 결과:
  [ ] PASS - 정상 종료
  [ ] FAIL - 오류 발생

소요 시간: ____초

결과 파일:
  - results/경로: ____________________________
  - 파일 크기: ____ MB
  - 영상 확인: [ ] 가능  [ ] 불가

GPU 최대 VRAM 사용량: ____ GB (nvidia-smi 또는 task manager 확인)

오류 메시지 (실패 시):
  ____________________________________________
  ____________________________________________

오류 분류 (실패 시):
  [ ] 설치/환경 오류 (ImportError, ModuleNotFoundError)
  [ ] CUDA 불일치 (sm_61, CUDA error)
  [ ] OOM (CUDA out of memory)
  [ ] weights 미로딩 (FileNotFoundError)
  [ ] 입력 포맷 불일치 (shape error)
  [ ] 기타: ____________________________
─────────────────────────────────────────────
```

### Phase 1a: 사용자 MP4 + 단일 마스크 (Phase 0 통과 후 진행)

```
실행 일시: ____-__-__ __:__
입력 영상: ________________________________________
마스크 파일: ______________________________________
자막 영역 좌표: (x1=___, y1=___, x2=___, y2=___)

실행 결과:
  [ ] PASS - 결과 영상 생성
  [ ] FAIL - 오류 발생

소요 시간: ____초
결과 파일: _________________________________________
VRAM 최대: ____ GB

자막 제거 품질 (육안 확인):
  [ ] 자막 완전 제거 (잔상 없음)
  [ ] 자막 대부분 제거 (미세 잔상 있음)
  [ ] 자막 제거 불완전 (뚜렷한 잔상)
  [ ] 플리커 현상 있음
```

---

## 4. 예상 성공 시나리오

```
Phase 0 성공 조건:
  - exit code 0
  - results/ 폴더에 MP4 또는 프레임 시퀀스 생성
  - OOM 없이 완료
  - 소요 시간 예상: 432x240, 7초(168프레임) 기준 3~10분

Phase 1a 성공 조건:
  - 사용자 영상에서 하단 자막 영역이 배경으로 채워짐
  - 오디오 보존 (원본 MP4 기준)
  - 전체 7초 영상 출력
```

---

## 5. 예상 실패 시나리오 및 대응

### 5.1 OOM (Out of Memory)

```
오류 메시지: RuntimeError: CUDA out of memory...
원인: VRAM 8GB 초과
즉시 대응:
  1. --subvideo_length 30 으로 감소
  2. --neighbor_length 3 으로 감소
  3. --width 320 --height 180 으로 해상도 추가 감소
  4. 시스템 다른 CUDA 프로세스 종료 후 재시도
```

### 5.2 sm_61 CUDA 커널 오류

```
오류 메시지: CUDA error: no kernel image is available for execution on the device
원인: PyTorch 버전과 GTX 1080 (sm_61) 호환 문제
즉시 대응:
  pip uninstall torch torchvision
  pip install torch==1.13.1+cu118 torchvision==0.14.1+cu118 \
    --index-url https://download.pytorch.org/whl/cu118
```

### 5.3 Weights 자동 다운로드 실패

```
오류 메시지: FileNotFoundError: weights/ProPainter.pth not found
원인: 인터넷 불안정 또는 GitHub Release 접근 실패
즉시 대응:
  수동 다운로드: https://github.com/sczhou/ProPainter/releases/tag/v0.1.0
  → ProPainter.pth, recurrent_flow_completion.pth, raft-things.pth
  → weights/ 폴더에 위치
```

### 5.4 av 패키지 오류

```
오류 메시지: ImportError: cannot import name 'av'
원인: av 패키지 Windows 빌드 실패
즉시 대응:
  conda install av -c conda-forge
```

### 5.5 입력 포맷 불일치

```
오류 메시지: AssertionError 또는 shape mismatch
원인: 프레임 수 ≠ 마스크 수, 또는 해상도 불일치
즉시 대응:
  - 프레임/마스크 수 재확인: ls frames/ | wc -l / ls masks/ | wc -l
  - 마스크를 단일 PNG 모드로 전환 (--mask single.png)
```

---

## 6. 결과 파일 경로 및 품질 체크

```
결과 기본 경로: ProPainter/results/{영상명}/
예상 파일 구조:
  results/
  └── running_car/
      ├── inpainted_frame_00000.jpg
      ├── inpainted_frame_00001.jpg
      ├── ...
      └── inpainted.mp4           ← 최종 출력 영상

품질 체크 항목:
  1. 자막 잔상 여부 (흰색 글자 흔적)
  2. 플리커 (프레임 간 인페인팅 영역 깜빡임)
  3. 경계선 자연스러움 (인페인팅 경계)
  4. 오디오 동기화 (별도 mux 필요할 수 있음)
```

---

## 7. 결과 보고 요약 (실행 후 기입)

```
현재 프로젝트 상태:     [실행 전 / 실행 중 / 완료]
Phase 0 통과 여부:      [미실행 / PASS / FAIL]
Phase 1a 통과 여부:     [미실행 / PASS / FAIL]
최대 VRAM 사용량:       ____ GB
소요 시간 (7초 영상):   ____ 분
결과 영상 생성 여부:    [미확인 / 성공 / 실패]
주요 오류:              ____________________________
품질 등급 (육안):       [미확인 / 양호 / 보통 / 불량]
다음 튜닝 포인트:       ____________________________
```

---

*작성: 원본 지우개 실행개발팀 | 2026-05-10*
*이 파일은 실행 전 템플릿. 실행 후 결과를 기입하여 완성.*
