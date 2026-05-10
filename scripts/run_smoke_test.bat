@echo off
REM =============================================================================
REM run_smoke_test.bat
REM 프로젝트: 원본 지우개
REM 목적: GTX 1080 8GB에서 ProPainter smoke test 실행 (Windows 배치 파일)
REM 버전: v1.0 | 기준일: 2026-05-10
REM =============================================================================
REM 사용법:
REM   run_smoke_test.bat [0|1a|1b]
REM   인자 없으면 Phase 0 (공식 샘플) 실행
REM
REM 사전 요건:
REM   1. conda activate propainter 실행 후 이 배치 파일 실행
REM   2. ProPainter 저장소 루트에서 실행
REM   3. weights/ 폴더에 모델 파일 존재 (또는 자동 다운로드)
REM =============================================================================

setlocal enabledelayedexpansion

REM ─── 파라미터 고정값 (parameter_lock.json 기준) ─────────────────────────────
set WIDTH=432
set HEIGHT=240
set FP16=--fp16
set SUBVIDEO_LENGTH=50
set NEIGHBOR_LENGTH=5
set REF_STRIDE=15

REM ─── Phase 선택 ──────────────────────────────────────────────────────────────
set PHASE=%1
if "%PHASE%"=="" set PHASE=0

echo ============================================================
echo   원본 지우개 - ProPainter Smoke Test Runner (Windows)
echo   대상 GPU: GTX 1080 8GB
echo   Phase: %PHASE%
echo ============================================================
echo.

REM ─── STEP 0: 환경 체크 ───────────────────────────────────────────────────────
echo [STEP 0] 환경 체크...
python --version
if %errorlevel% neq 0 (
    echo [FAIL] Python 실행 불가. conda activate propainter 확인
    exit /b 1
)

python -c "import torch; ok='OK' if torch.cuda.is_available() else 'FAIL'; print('CUDA:', ok)"
python -c "import torch; print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'NONE')"
python -c "import torch; mem=torch.cuda.get_device_properties(0).total_memory/1024**3 if torch.cuda.is_available() else 0; print(f'VRAM: {mem:.1f} GB')"
echo.

REM ─── STEP 0b: Weights 체크 ────────────────────────────────────────────────
echo [STEP 0b] Weights 체크...
if exist "weights\ProPainter.pth" (
    echo   OK weights\ProPainter.pth
) else (
    echo   MISSING weights\ProPainter.pth - 자동 다운로드 시도됨
)
if exist "weights\recurrent_flow_completion.pth" (
    echo   OK weights\recurrent_flow_completion.pth
) else (
    echo   MISSING weights\recurrent_flow_completion.pth
)
if exist "weights\raft-things.pth" (
    echo   OK weights\raft-things.pth
) else (
    echo   MISSING weights\raft-things.pth
)
echo.

REM ─── STEP 1: 입력 구성 ────────────────────────────────────────────────────
if "%PHASE%"=="0" (
    echo [STEP 1] Phase 0 - 공식 샘플 입력 (running_car.mp4)
    set VIDEO_INPUT=inputs\video_completion\running_car.mp4
    set MASK_INPUT=inputs\video_completion\mask_square.png

    if not exist "!VIDEO_INPUT!" (
        echo [FAIL] 공식 샘플 없음: !VIDEO_INPUT!
        echo ProPainter 저장소 루트에서 실행 확인
        exit /b 1
    )
    echo   OK 입력 비디오: !VIDEO_INPUT!
    echo   OK 마스크: !MASK_INPUT!

) else if "%PHASE%"=="1a" (
    echo [STEP 1] Phase 1a - 사용자 7초 테스트 (MP4 + 단일 마스크)
    set VIDEO_INPUT=inputs_user\test_7s_single\your_7s_video.mp4
    set MASK_INPUT=inputs_user\test_7s_single\mask_subtitle.png

    if not exist "!VIDEO_INPUT!" (
        echo [FAIL] 사용자 영상 없음: !VIDEO_INPUT!
        echo 7초 MP4를 inputs_user\test_7s_single\your_7s_video.mp4 로 배치
        exit /b 1
    )
    if not exist "!MASK_INPUT!" (
        echo [INFO] 마스크 없음. 자동 생성 시도...
        if not exist "inputs_user\test_7s_single" mkdir "inputs_user\test_7s_single"
        python -c "from PIL import Image,ImageDraw;import os;W,H=432,240;mask=Image.new('L',(W,H),0);draw=ImageDraw.Draw(mask);draw.rectangle([0,190,432,240],fill=255);mask.save('inputs_user/test_7s_single/mask_subtitle.png');print('마스크 자동 생성 완료')"
    )
    echo   OK 입력 비디오: !VIDEO_INPUT!
    echo   OK 마스크: !MASK_INPUT!

) else if "%PHASE%"=="1b" (
    echo [STEP 1] Phase 1b - 사용자 7초 테스트 (프레임 폴더 + 마스크 폴더)
    set VIDEO_INPUT=inputs_user\test_7s\frames
    set MASK_INPUT=inputs_user\test_7s\masks

    if not exist "!VIDEO_INPUT!" (
        echo [FAIL] 프레임 폴더 없음: !VIDEO_INPUT!
        echo input_folder_spec.md 참조하여 준비
        exit /b 1
    )
    echo   OK 프레임 폴더: !VIDEO_INPUT!
    echo   OK 마스크 폴더: !MASK_INPUT!

) else (
    echo [FAIL] 알 수 없는 Phase: %PHASE%
    echo 사용법: run_smoke_test.bat [0^|1a^|1b]
    exit /b 1
)

echo.

REM ─── STEP 2: 실행 ─────────────────────────────────────────────────────────
echo [STEP 2] ProPainter 실행
echo.
echo   파라미터:
echo     --width           %WIDTH%
echo     --height          %HEIGHT%
echo     --fp16            true
echo     --subvideo_length %SUBVIDEO_LENGTH%
echo     --neighbor_length %NEIGHBOR_LENGTH%
echo     --ref_stride      %REF_STRIDE%
echo.

echo [시작] %date% %time%
echo ─────────────────────────────────────────────

python inference_propainter.py ^
  --video "!VIDEO_INPUT!" ^
  --mask "!MASK_INPUT!" ^
  --height %HEIGHT% ^
  --width %WIDTH% ^
  %FP16% ^
  --subvideo_length %SUBVIDEO_LENGTH% ^
  --neighbor_length %NEIGHBOR_LENGTH% ^
  --ref_stride %REF_STRIDE%

set EXIT_CODE=%errorlevel%
echo ─────────────────────────────────────────────
echo [종료] %date% %time%
echo.

REM ─── STEP 3: 결과 확인 ────────────────────────────────────────────────────
echo [STEP 3] 결과 확인

if %EXIT_CODE%==0 (
    echo   [PASS] ProPainter 정상 종료
    echo.
    echo   results\ 폴더 확인:
    if exist "results" (
        dir /b /s "results\*.mp4" 2>nul || echo   MP4 없음 (프레임만 생성됨)
    ) else (
        echo   results\ 폴더 없음
    )
    echo.
    echo ============================================================
    echo   SMOKE TEST RESULT: PASS
    echo   Phase: %PHASE%
    echo ============================================================
) else (
    echo   [FAIL] ProPainter 비정상 종료 (exit code %EXIT_CODE%)
    echo.
    echo   오류 분류 가이드:
    echo   CUDA error           : CUDA/드라이버 버전 불일치
    echo   CUDA out of memory   : OOM - fallback 파라미터 사용
    echo   ModuleNotFoundError  : pip install -r requirements.txt
    echo   FileNotFoundError    : weights/ 또는 입력 파일 경로 확인
    echo   RuntimeError (sm_61) : PyTorch 1.13.1+cu118으로 다운그레이드
    echo.
    echo   Fallback 명령:
    echo   python inference_propainter.py ^
    echo     --video !VIDEO_INPUT! --mask !MASK_INPUT! ^
    echo     --height 180 --width 320 --fp16 ^
    echo     --subvideo_length 30 --neighbor_length 3 --ref_stride 20
    echo.
    echo ============================================================
    echo   SMOKE TEST RESULT: FAIL (exit code %EXIT_CODE%)
    echo ============================================================
    exit /b %EXIT_CODE%
)

endlocal
