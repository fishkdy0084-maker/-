# next_actions.md
# 다음 액션 플랜 - 원본 지우개
# 버전: v1.0 | 기준일: 2026-05-10

---

## 현재 상태 요약

```
- 실행 환경 문서화:    ✅ 완료 (docs/environment_setup.md)
- 입력 구조 고정:      ✅ 완료 (docs/input_folder_spec.md)
- 파라미터 고정:       ✅ 완료 (parameter_lock.json)
- 실행 스크립트:       ✅ 완료 (scripts/run_smoke_test.sh / .bat)
- 결과 보고 템플릿:    ✅ 완료 (docs/result_report.md)
- ProPainter 설치:     ⬜ 로컬 PC에서 미실행 (이 샌드박스는 CUDA 없음)
- Smoke Test Phase 0:  ⬜ 미실행 - 로컬 GTX 1080 PC에서 실행 필요
- Smoke Test Phase 1a: ⬜ 미실행 - Phase 0 통과 후 진행
```

---

## 즉시 수행 액션 (오늘)

### [A1] 로컬 PC에서 환경 셋업 시작 ⭐ 최우선

```
담당: 개발자 (GTX 1080 PC 접속)
소요 예상: 30분~1시간

실행 순서:
1. environment_setup.md Step 1~7 순서대로 실행
2. nvidia-smi 로 드라이버 확인
3. conda create -n propainter python=3.8 -y
4. conda activate propainter
5. pip install torch==2.0.1+cu118 torchvision==0.15.2+cu118 ...
6. git clone https://github.com/sczhou/ProPainter.git
7. pip install -r requirements.txt
8. 검증 체크리스트 전부 통과 확인
```

### [A2] Smoke Test Phase 0 실행

```
담당: 개발자
소요 예상: 3~10분 (실행 시간)

실행 방법:
cd ProPainter
# Windows:
scripts\run_smoke_test.bat 0
# 또는 Linux/Mac:
bash scripts/run_smoke_test.sh 0

성공 기준:
- exit code 0
- results/ 폴더에 영상 파일 존재
- OOM 없음
```

### [A3] 결과 기록 (result_report.md 기입)

```
Phase 0 결과를 docs/result_report.md 섹션 3에 기입:
- 소요 시간
- VRAM 최대 사용량 (nvidia-smi 또는 Task Manager)
- 결과 파일 경로
- 오류 여부
```

---

## Phase 0 PASS 시 다음 액션

### [B1] 사용자 7초 영상 준비

```
작업:
1. 7초 중국 원본 영상 추출 또는 준비
2. FFmpeg으로 프레임 추출 및 432x240 리사이즈:

ffmpeg -i original.mp4 -ss 00:00:00 -t 00:00:07 \
  -vf "scale=432:240" -q:v 2 \
  inputs_user/test_7s_single/your_7s_video.mp4

3. 자막 영역 좌표 확인 (영상 열어서 픽셀 좌표 측정)
```

### [B2] 자막 마스크 생성

```
방법 A - 단일 PNG 마스크 (권장, 가장 빠름):
  - 자막이 항상 같은 위치에 있을 경우
  - scripts/gen_subtitle_mask.py 수정 후 실행
  - 또는 Photoshop/GIMP로 직접 그려도 됨

방법 B - 프레임별 마스크 (자막 위치가 변할 경우):
  - 각 프레임마다 마스크 PNG 생성 필요
  - 1차 테스트에서는 방법 A 우선 권장
```

### [B3] Phase 1a Smoke Test 실행

```
# 7초 MP4 + 단일 마스크
run_smoke_test.bat 1a
# 또는
bash scripts/run_smoke_test.sh 1a
```

---

## Phase 1a PASS 시 다음 액션

### [C1] 품질 평가 및 튜닝

```
자막 잔상이 남을 경우:
1. 마스크 영역 10~15px 확장 (패딩 추가)
2. neighbor_length를 7~10으로 늘리기
3. ref_stride를 10으로 줄이기 (참조 품질 향상)

플리커 발생 시:
1. subvideo_length를 80으로 늘리기 (VRAM 여유 있을 경우)
2. neighbor_length 증가

품질 vs 속도 트레이드오프:
- 품질 우선: neighbor_length=10, ref_stride=10, subvideo_length=60
- 속도 우선: neighbor_length=3, ref_stride=20, subvideo_length=30
```

### [C2] 오디오 합성 (결과 영상에 원본 오디오 추가)

```
ProPainter 출력은 무음 영상. 원본 오디오 합성 필요:

ffmpeg -i results/your_video/inpainted.mp4 \
       -i your_original_7s.mp4 \
       -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 \
       results/your_video/inpainted_with_audio.mp4
```

### [C3] 전체 영상으로 확장 실험

```
7초 테스트 성공 후 30초 → 1분 → 전체 영상 순으로 확장
- 전체 영상은 청크 분할 후 병렬 처리 계획 필요 (Phase 2)
```

---

## Phase 0 FAIL 시 대응 액션

### [FAIL-1] OOM 발생

```
즉시 조치:
1. parameter_lock.json fallback_params 적용
2. 명령:
   python inference_propainter.py \
     --video inputs/video_completion/running_car.mp4 \
     --mask inputs/video_completion/mask_square.png \
     --height 180 --width 320 --fp16 \
     --subvideo_length 30 --neighbor_length 3 --ref_stride 20

성공 시: parameter_lock.json 업데이트 후 Phase 0 재시도 (fallback 파라미터 기준)
계속 실패 시: PyTorch 1.13.1 다운그레이드 시도
```

### [FAIL-2] CUDA 불일치 / sm_61 오류

```
즉시 조치:
pip uninstall torch torchvision -y
pip install torch==1.13.1+cu118 torchvision==0.14.1+cu118 \
  --index-url https://download.pytorch.org/whl/cu118
재실행
```

### [FAIL-3] av / 기타 패키지 오류

```
즉시 조치:
conda install av -c conda-forge
pip install --upgrade timm==0.6.13
```

### [FAIL-4] 설치 자체 불가

```
대안:
1. Google Colab 사용 (T4 GPU 무료)
   → https://colab.research.google.com
   → GPU 런타임 선택 후 공식 Quick test 명령 실행
   → 설치 검증 목적으로만 사용

2. HuggingFace Space 사용 (데모 수준)
   → https://huggingface.co/spaces/sczhou/ProPainter
```

---

## 파라미터 튜닝 로드맵

```
1차 (안전):  432x240, fp16, subvideo=50, neighbor=5, ref_stride=15
  ↓ PASS 확인 후
2차 (균형):  432x240, fp16, subvideo=60, neighbor=7, ref_stride=10
  ↓ VRAM 여유 확인 후
3차 (품질):  432x240, fp16, subvideo=80, neighbor=10, ref_stride=10
  ↓ OOM 없으면
4차 (해상도): 720x480, fp16, subvideo=50, neighbor=5, ref_stride=15
```

---

## 이후 Phase 2 예고 (본편 착수 전 준비)

```
Phase 2 진입 조건:
  - Phase 1a PASS (7초 테스트 1회 성공)
  - 품질 육안 검수 합격
  - 재현 가능한 파라미터 세트 고정

Phase 2 작업 목록:
  1. 자막 자동 마스크 생성 (EasyOCR 또는 PaddleOCR 연동)
  2. 긴 영상 청크 분할 처리 스크립트
  3. 오디오 자동 합성 파이프라인
  4. 배치 처리 자동화 (watch 폴더 기반)
  5. 품질 검수 자동화 (잔상 감지)
```

---

*작성: 원본 지우개 실행개발팀 | 2026-05-10*
