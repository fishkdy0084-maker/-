@echo off
setlocal enabledelayedexpansion

REM =========================================================
REM [오버레이형] smoke test 실행
REM 전제: setup_propainter.bat 으로 설치 + Quick Test 완료
REM =========================================================
REM   run_smoke_test.bat       → Phase 0 (공식 샘플 재실행)
REM   run_smoke_test.bat 0     → Phase 0
REM   run_smoke_test.bat 1     → Phase 1 (7초 텍스트 제거)
REM =========================================================

set PHASE=%1
if "%PHASE%"=="" set PHASE=0

REM GPU 0=Intel UHD 770, GPU 1=GTX 1080
set CUDA_VISIBLE_DEVICES=1

echo =========================================================
echo  Smoke Test - Phase %PHASE%
echo  CUDA_VISIBLE_DEVICES=%CUDA_VISIBLE_DEVICES%
echo =========================================================
echo.

REM === [1/6] 전제조건 확인 ===
echo [1/6] 전제조건 확인

if not exist inference_propainter.py (
    echo [FAIL] inference_propainter.py 없음.
    echo   이 bat은 ProPainter 루트 폴더에서 실행해야 합니다.
    echo   먼저 setup_propainter.bat 으로 설치하세요.
    goto :fail
)

call conda activate propainter >nul 2>&1
python -c "import torch; assert torch.cuda.is_available(), 'NO CUDA'" >nul 2>&1
if %errorlevel% neq 0 (
    echo [FAIL] torch/CUDA 사용 불가
    echo   setup_propainter.bat 을 먼저 실행하세요.
    goto :fail
)
echo   ProPainter 루트: OK
echo   torch/CUDA: OK
echo.

REM === [2/6] 폴더 자동 생성 ===
echo [2/6] 폴더 구조 생성
if not exist logs mkdir logs
if not exist output mkdir output
if not exist results mkdir results
if not exist input\video mkdir input\video
if not exist input\masks\test_mask mkdir input\masks\test_mask
echo   logs, output, results, input 구조: OK
echo.

REM === [3/6] 입력 경로 설정 ===
if "%PHASE%"=="0" (
    echo [3/6] Phase 0 - 공식 샘플
    set VIDEO_PATH=inputs\video_completion\running_car.mp4
    set MASK_PATH=inputs\video_completion\mask_square.png
    set OUTPUT_LOG=logs\phase0.log
    set RESULT_FILE=results\running_car\inpaint_out.mp4

    if not exist "!VIDEO_PATH!" (
        echo [FAIL] 공식 샘플 없음: !VIDEO_PATH!
        goto :fail
    )
) else if "%PHASE%"=="1" (
    echo [3/6] Phase 1 - 7초 테스트
    set VIDEO_PATH=input\video\test_input.mp4
    set MASK_PATH=input\masks\test_mask
    set OUTPUT_LOG=logs\phase1.log
    set RESULT_FILE=results\test_input\inpaint_out.mp4

    if not exist "!VIDEO_PATH!" (
        echo [FAIL] 테스트 영상 없음: !VIDEO_PATH!
        echo   smoke test 패키지의 input 폴더를 이 위치에 복사하세요.
        goto :fail
    )
    REM 마스크 폴더에 파일이 있는지 확인
    dir /b "!MASK_PATH!\*.png" >nul 2>&1
    if %errorlevel% neq 0 (
        echo [FAIL] 마스크 없음: !MASK_PATH!\*.png
        echo   smoke test 패키지의 input\masks\test_mask 를 복사하세요.
        goto :fail
    )
) else (
    echo [FAIL] 알 수 없는 Phase: %PHASE% (0 또는 1)
    goto :fail
)
echo   VIDEO: !VIDEO_PATH!
echo   MASK:  !MASK_PATH!
echo.

REM === [4/6] 실행 ===
echo [4/6] ProPainter 실행
echo   파라미터: 432x240 fp16 subvideo=50 neighbor=5 ref_stride=15
echo   로그: !OUTPUT_LOG!
echo.

python inference_propainter.py ^
  --video "!VIDEO_PATH!" ^
  --mask "!MASK_PATH!" ^
  --height 240 ^
  --width 432 ^
  --fp16 ^
  --subvideo_length 50 ^
  --neighbor_length 5 ^
  --ref_stride 15 > "!OUTPUT_LOG!" 2>&1

set EXIT_CODE=%errorlevel%

REM === [5/6] 결과 확인 ===
echo [5/6] 결과 확인

if %EXIT_CODE%==0 (
    if exist "!RESULT_FILE!" (
        echo   [PASS] exit 0, 결과 파일 생성됨
        echo   결과: !RESULT_FILE!
    ) else (
        echo   [WARN] exit 0이지만 결과 파일 없음: !RESULT_FILE!
        echo   로그 확인: type "!OUTPUT_LOG!"
    )
) else (
    echo   [FAIL] exit code %EXIT_CODE%
    echo.
    echo   로그 마지막 20줄:
    powershell -command "Get-Content '!OUTPUT_LOG!' -Tail 20" 2>nul
    echo.
    echo   오류 분류:
    echo     CUDA out of memory  → OOM
    echo     CUDA error          → CUDA/드라이버
    echo     ModuleNotFoundError → pip install
    echo     FileNotFoundError   → weights/입력 경로
)
echo.

REM === [6/6] 요약 ===
echo [6/6] 요약
echo   Phase:     %PHASE%
echo   Exit code: %EXIT_CODE%
echo   Log:       !OUTPUT_LOG!
echo   Result:    !RESULT_FILE!

if %EXIT_CODE% neq 0 (
    echo.
    echo   OOM 시 축소 재시도 명령:
    echo   set CUDA_VISIBLE_DEVICES=1
    echo   python inference_propainter.py --video "!VIDEO_PATH!" --mask "!MASK_PATH!" --height 176 --width 320 --fp16 --subvideo_length 30 --neighbor_length 3 --ref_stride 20
    goto :fail
)

goto :end

:fail
echo.
echo =========================================================
echo  SMOKE TEST: FAIL (Phase %PHASE%)
echo =========================================================

:end
endlocal
pause
