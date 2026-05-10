# next_actions.md
# 원본 지우개 — 다음 액션 (v2)

---

## 현재 상태 (v2 EXECUTION_HANDOFF 기준)

```
환경 문서:           ✅ environment_setup.md
입력 구조:           ✅ input_folder_spec.md (실제 영상 메타데이터 반영)
파라미터 잠금:       ✅ parameter_lock.json (test_video 섹션 추가)
실행 스크립트:       ✅ run_smoke_test.bat / .sh (Phase 0/1 지원)
결과 보고 양식:      ✅ result_report.md (Phase 0/1 분리)
OCR 마스크 생성기:   ✅ gen_masks.py
테스트 영상:         ✅ input/video/test_input.mp4 (H.264, 480x854, 168프레임)
프레임별 마스크:     ✅ input/masks/test_mask/ (168장, OCR 기반)
실제 설치:           ⬜ 로컬 PC에서 미실행
Phase 0 실행:        ⬜ 미실행
Phase 1 실행:        ⬜ 미실행
```

---

## 실행 순서 (로컬 PC에서 수행)

### Step 1. 환경 세팅 (최초 1회)

`environment_setup.md`를 따라 진행한다.

```bat
conda create -n propainter python=3.8 -y
conda activate propainter
pip install torch==2.0.1+cu118 torchvision==0.15.2+cu118 --index-url https://download.pytorch.org/whl/cu118
git clone https://github.com/sczhou/ProPainter.git
cd ProPainter
pip install -r requirements.txt
```

### Step 2. GPU 인식 확인

```bat
set CUDA_VISIBLE_DEVICES=1
python -c "import torch; print(torch.cuda.get_device_name(0))"
```

**기대 출력:** `NVIDIA GeForce GTX 1080`

### Step 3. 실행 패키지 복사

이 저장소의 파일들을 로컬 ProPainter 폴더에 복사한다:

```
복사 대상 (이 저장소 → ProPainter 폴더):

  input/video/test_input.mp4         → ProPainter/input/video/test_input.mp4
  input/masks/test_mask/             → ProPainter/input/masks/test_mask/
    (00001.png ~ 00168.png, 168장)
  run_smoke_test.bat                 → ProPainter/run_smoke_test.bat
  run_smoke_test.sh                  → ProPainter/run_smoke_test.sh
  parameter_lock.json                → ProPainter/parameter_lock.json
  result_report.md                   → ProPainter/result_report.md
  gen_masks.py                       → ProPainter/gen_masks.py (참조용)
```

Windows 명령:
```bat
cd ProPainter
mkdir input\video
mkdir input\masks\test_mask
copy /Y "다운로드경로\test_input.mp4" input\video\
xcopy /E /Y "다운로드경로\test_mask\*" input\masks\test_mask\
copy /Y "다운로드경로\run_smoke_test.bat" .
copy /Y "다운로드경로\parameter_lock.json" .
copy /Y "다운로드경로\result_report.md" .
```

### Step 4. Phase 0 실행 (공식 샘플)

```bat
run_smoke_test.bat 0
```

**성공 기준:**
- `results/running_car/inpaint_out.mp4` 생성
- OOM 없음
- exit code 0

**실패 시:** 아래 [트러블슈팅] 참조

### Step 5. Phase 0 결과 기록

`result_report.md`의 Phase 0 섹션에 기입:
- 실행 일시, 소요 시간, VRAM 최대 사용량
- PASS/FAIL 체크

### Step 6. Phase 1 실행 (7초 테스트)

```bat
run_smoke_test.bat 1
```

**성공 기준:**
- `results/test_input/inpaint_out.mp4` 생성
- 영상 재생 시 말풍선 텍스트 일부라도 제거
- OOM 없음

### Step 7. Phase 1 결과 기록 + 보고

`result_report.md`의 Phase 1 섹션에 기입.
텍스트 제거 품질 육안 평가.

---

## 트러블슈팅

### OOM 발생 시 (Phase 0 또는 Phase 1)

Fallback 파라미터로 재실행:

```bat
set CUDA_VISIBLE_DEVICES=1
python inference_propainter.py ^
  --video [VIDEO_PATH] --mask [MASK_PATH] ^
  --height 176 --width 320 --fp16 ^
  --subvideo_length 30 --neighbor_length 3 --ref_stride 20
```

### CUDA 오류 (sm_61 관련)

PyTorch 다운그레이드:
```bat
pip install torch==1.13.1+cu118 torchvision==0.14.1+cu118 --index-url https://download.pytorch.org/whl/cu118
```

### av 패키지 오류

```bat
conda install av -c conda-forge
```

### timm 버전 문제

```bat
pip install timm==0.6.13
```

### 동일 오류 2회 반복 시

1. 원인 분류를 `result_report.md`에 기록
2. 총괄에게 보고
3. Plan B 전환 검토

---

## Phase 1 PASS 후 — 품질 튜닝 로드맵

```
Step  해상도    subvideo  neighbor  ref_stride  비고
1차   432x240   50        5         15          현재 파라미터
2차   432x240   60        7         10          참조 프레임 증가
3차   432x240   80        10        10          기본값 복원
4차   720x480   50        5         15          해상도 업
```

각 단계는 반드시 이전 단계 PASS 후에만 진행한다.

---

## Plan B 전환 조건

아래 중 하나라도 해당되면 Plan B (외부 GPU/API) 전환:

- [x] OOM이 fallback 파라미터에서도 반복
- [x] CUDA 런타임 오류 해결 불가
- [x] Phase 0 공식 샘플조차 PASS 불가
- [x] 결과 파일 미생성

---

*원본 지우개 실행개발팀 | 2026-05-10 | v2 EXECUTION_HANDOFF*
