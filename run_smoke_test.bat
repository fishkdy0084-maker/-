@echo off
REM ============================================================
REM run_smoke_test.bat
REM 원본 지우개 - ProPainter Smoke Test (Windows)
REM 대상: GTX 1080 8GB / parameter_lock.json 기준
REM ============================================================
REM 사용법:
REM   run_smoke_test.bat         → Phase 0 (공식 샘플)
REM   run_smoke_test.bat 0       → Phase 0 (공식 샘플)
REM   run_smoke_test.bat 1       → Phase 1 (사용자 7초 테스트)
REM
REM 사전 요건:
REM   conda activate propainter
REM   ProPainter 저장소 루트에서 실행
REM ============================================================

setlocal enabledelayedexpansion

set PHASE=%1
if "%PHASE%"=="" set PHASE=0

REM --- GPU 선택 (GPU 0 = Intel UHD, GPU 1 = GTX 1080) ---
set CUDA_VISIBLE_DEVICES=1

REM --- 파라미터 고정값 ---
set WIDTH=432
set HEIGHT=240
set SUBVIDEO_LENGTH=50
set NEIGHBOR_LENGTH=5
set REF_STRIDE=15

echo ============================================================
echo   원본 지우개 - ProPainter Smoke Test
echo   GPU: GTX 1080 8GB (CUDA_VISIBLE_DEVICES=%CUDA_VISIBLE_DEVICES%)
echo   Phase: %PHASE%
echo ============================================================
echo.

REM === STEP 0: 환경 체크 ===
echo [STEP 0] 환경 체크
python --version
if %errorlevel% neq 0 (
    echo [FAIL] Python 없음. conda activate propainter 확인
    exit /b 1
)
python -c "import torch; print('torch:', torch.__version__); print('CUDA:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'NONE')"
if %errorlevel% neq 0 (
    echo [FAIL] torch 확인 실패
    exit /b 1
)
echo.

REM === STEP 0b: Weights 체크 ===
echo [STEP 0b] Weights 체크
if exist "weights\ProPainter.pth" (echo   OK ProPainter.pth) else (echo   MISSING ProPainter.pth)
if exist "weights\recurrent_flow_completion.pth" (echo   OK recurrent_flow_completion.pth) else (echo   MISSING recurrent_flow_completion.pth)
if exist "weights\raft-things.pth" (echo   OK raft-things.pth) else (echo   MISSING raft-things.pth)
echo.

REM === STEP 1: 입력 구성 ===
if "%PHASE%"=="0" (
    echo [STEP 1] Phase 0 - 공식 샘플
    set VIDEO_INPUT=inputs/video_completion/running_car.mp4
    set MASK_INPUT=inputs/video_completion/mask_square.png
    set LOG_FILE=logs/phase0.log

    if not exist "inputs\video_completion\running_car.mp4" (
        echo [FAIL] 공식 샘플 없음. ProPainter 루트에서 실행 확인.
        exit /b 1
    )
) else if "%PHASE%"=="1" (
    echo [STEP 1] Phase 1 - 사용자 7초 테스트
    set VIDEO_INPUT=input/video/test_input.mp4
    set MASK_INPUT=input/masks/test_mask.png
    set LOG_FILE=logs/phase1.log

    if not exist "input\video\test_input.mp4" (
        echo [FAIL] 사용자 영상 없음: input\video\test_input.mp4
        echo input_folder_spec.md 참조
        exit /b 1
    )
    if not exist "input\masks\test_mask.png" (
        if not exist "input\masks\test_mask" (
            echo [FAIL] 마스크 없음. input_folder_spec.md 참조
            exit /b 1
        ) else (
            set MASK_INPUT=input/masks/test_mask
        )
    )
) else (
    echo [FAIL] 알 수 없는 Phase: %PHASE%
    echo 사용법: run_smoke_test.bat [0^|1]
    exit /b 1
)

echo   영상: !VIDEO_INPUT!
echo   마스크: !MASK_INPUT!
echo.

REM === STEP 2: 실행 ===
if not exist "logs" mkdir logs

echo [STEP 2] ProPainter 실행
echo.
echo   고정 파라미터:
echo     --width           %WIDTH%
echo     --height          %HEIGHT%
echo     --fp16
echo     --subvideo_length %SUBVIDEO_LENGTH%
echo     --neighbor_length %NEIGHBOR_LENGTH%
echo     --ref_stride      %REF_STRIDE%
echo.

set CMD=python inference_propainter.py --video "!VIDEO_INPUT!" --mask "!MASK_INPUT!" --height %HEIGHT% --width %WIDTH% --fp16 --subvideo_length %SUBVIDEO_LENGTH% --neighbor_length %NEIGHBOR_LENGTH% --ref_stride %REF_STRIDE%

echo   명령: %CMD%
echo.
echo [시작] %date% %time%
echo ─────────────────────────────────────

%CMD% 2>&1 | tee !LOG_FILE!
set EXIT_CODE=%errorlevel%

echo ─────────────────────────────────────
echo [종료] %date% %time%
echo.

REM === STEP 3: 결과 확인 ===
echo [STEP 3] 결과 확인

if %EXIT_CODE%==0 (
    echo   [PASS] 정상 종료
    echo.
    if exist "results" (
        echo   results\ 내용:
        dir /b /s "results\*.mp4" 2>nul
        if %errorlevel% neq 0 (
            echo   MP4 없음
        )
    )
    echo.
    echo ============================================================
    echo   SMOKE TEST: PASS (Phase %PHASE%)
    echo   로그: !LOG_FILE!
    echo ============================================================
) else (
    echo   [FAIL] 비정상 종료 (exit code %EXIT_CODE%)
    echo.
    echo   오류 분류 가이드:
    echo     CUDA out of memory  → OOM: fallback 파라미터 적용
    echo     CUDA error           → CUDA/드라이버 불일치
    echo     ModuleNotFoundError  → pip install -r requirements.txt
    echo     FileNotFoundError    → weights/ 또는 입력 파일 확인
    echo.
    echo   Fallback 명령:
    echo   python inference_propainter.py ^
    echo     --video !VIDEO_INPUT! --mask !MASK_INPUT! ^
    echo     --height 176 --width 320 --fp16 ^
    echo     --subvideo_length 30 --neighbor_length 3 --ref_stride 20
    echo.
    echo ============================================================
    echo   SMOKE TEST: FAIL (Phase %PHASE%, exit code %EXIT_CODE%)
    echo   로그: !LOG_FILE!
    echo ============================================================
    exit /b %EXIT_CODE%
)

endlocal
