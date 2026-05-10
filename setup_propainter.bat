@echo off
setlocal enabledelayedexpansion

REM =========================================================
REM [설치형] ProPainter 설치 + Quick Test
REM 대상: ProPainter가 없는 Windows PC (GTX 1080 8GB)
REM 전제: Git, Conda 설치 완료
REM =========================================================
REM 사용법:
REM   1. 이 파일을 작업 폴더(예: C:\work)에 넣는다
REM   2. Anaconda Prompt를 열고 해당 폴더로 이동한다
REM   3. setup_propainter.bat 을 실행한다
REM =========================================================

echo =========================================================
echo  ProPainter 설치 + Quick Test
echo  Plan A / GTX 1080 8GB
echo =========================================================
echo.

REM === [1/10] 전제조건 확인 ===
echo [1/10] 전제조건 확인
echo.

git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [FAIL] Git이 설치되어 있지 않습니다.
    echo   설치: https://git-scm.com/download/win
    goto :fail
)
echo   Git: OK

conda --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [FAIL] Conda가 설치되어 있지 않습니다.
    echo   설치: https://docs.conda.io/en/latest/miniconda.html
    goto :fail
)
echo   Conda: OK

where ffmpeg >nul 2>&1
if %errorlevel% neq 0 (
    echo   [WARN] ffmpeg이 PATH에 없습니다. ProPainter 실행엔 필수는 아니지만 권장합니다.
    echo   설치: https://ffmpeg.org/download.html
) else (
    echo   ffmpeg: OK
)
echo.

REM === [2/10] ProPainter 저장소 clone ===
echo [2/10] ProPainter 저장소 clone

if exist ProPainter (
    echo   ProPainter 폴더가 이미 존재합니다. 기존 폴더를 사용합니다.
) else (
    git clone https://github.com/sczhou/ProPainter.git
    if %errorlevel% neq 0 (
        echo [FAIL] git clone 실패
        goto :fail
    )
)
cd ProPainter
echo   현재 위치: %CD%
echo.

REM === [3/10] conda 환경 생성 ===
echo [3/10] conda 환경 생성 (propainter / Python 3.8)

call conda create -n propainter python=3.8 -y
if %errorlevel% neq 0 (
    echo [WARN] 환경 생성 실패. 이미 존재할 수 있습니다.
)

call conda activate propainter
if %errorlevel% neq 0 (
    echo [FAIL] conda activate propainter 실패
    goto :fail
)
echo   Python:
python --version
echo.

REM === [4/10] PyTorch + CUDA 설치 (GTX 1080 = sm_61 = cu118) ===
echo [4/10] PyTorch 2.0.1 + CUDA 11.8 설치

pip install torch==2.0.1+cu118 torchvision==0.15.2+cu118 --index-url https://download.pytorch.org/whl/cu118
if %errorlevel% neq 0 (
    echo [FAIL] PyTorch 설치 실패
    goto :fail
)
echo.

REM === [5/10] ProPainter 의존성 설치 ===
echo [5/10] requirements.txt 설치

pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo [WARN] 일부 패키지 설치 실패. av 문제라면 아래 시도:
    echo   conda install av -c conda-forge
)

REM timm 버전 고정 (ProPainter 호환)
pip install timm==0.6.13
echo.

REM === [6/10] GPU 선택 + CUDA 인식 확인 ===
echo [6/10] GPU / CUDA 인식 확인

REM GPU 0=Intel UHD 770, GPU 1=GTX 1080
set CUDA_VISIBLE_DEVICES=1

python -c "import torch; print('torch:', torch.__version__); print('CUDA:', torch.cuda.is_available()); print('GPU count:', torch.cuda.device_count()); print('GPU 0:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'NO_GPU')"
if %errorlevel% neq 0 (
    echo [FAIL] torch/CUDA 확인 실패
    goto :fail
)
echo.

REM === [7/10] pyav 확인 ===
echo [7/10] pyav (av 패키지) 확인

python -c "import av; print('pyav:', av.__version__)"
if %errorlevel% neq 0 (
    echo [WARN] av 패키지 없음. conda로 설치 시도:
    conda install av -c conda-forge -y
    python -c "import av; print('pyav:', av.__version__)"
    if %errorlevel% neq 0 (
        echo [FAIL] av 설치 실패
        goto :fail
    )
)
echo.

REM === [8/10] weights 폴더 확인 ===
echo [8/10] weights 확인

if not exist weights mkdir weights

REM ProPainter는 첫 실행 시 자동 다운로드한다.
REM 수동 다운로드가 필요하면:
REM   https://github.com/sczhou/ProPainter/releases/download/v0.1.0/ProPainter.pth
REM   https://github.com/sczhou/ProPainter/releases/download/v0.1.0/recurrent_flow_completion.pth
REM   https://github.com/sczhou/ProPainter/releases/download/v0.1.0/raft-things.pth

if exist weights\ProPainter.pth (
    echo   ProPainter.pth: OK
) else (
    echo   ProPainter.pth: 미존재 (첫 실행 시 자동 다운로드)
)
if exist weights\recurrent_flow_completion.pth (
    echo   recurrent_flow_completion.pth: OK
) else (
    echo   recurrent_flow_completion.pth: 미존재 (첫 실행 시 자동 다운로드)
)
if exist weights\raft-things.pth (
    echo   raft-things.pth: OK
) else (
    echo   raft-things.pth: 미존재 (첫 실행 시 자동 다운로드)
)
echo.

REM === [9/10] 공식 샘플 확인 ===
echo [9/10] 공식 샘플 확인

if not exist inputs\video_completion\running_car.mp4 (
    echo [FAIL] 공식 샘플 없음: inputs\video_completion\running_car.mp4
    echo   ProPainter 저장소에 포함되어야 합니다. git clone을 다시 확인하세요.
    goto :fail
)
echo   running_car.mp4: OK
echo   mask_square.png: 
if exist inputs\video_completion\mask_square.png (echo OK) else (echo MISSING)
echo.

REM === [10/10] Quick Test 실행 ===
echo [10/10] Quick Test 실행 (공식 샘플)
echo.

if not exist logs mkdir logs

set CUDA_VISIBLE_DEVICES=1
echo   CUDA_VISIBLE_DEVICES=%CUDA_VISIBLE_DEVICES%
echo   명령: python inference_propainter.py --video inputs/video_completion/running_car.mp4 --mask inputs/video_completion/mask_square.png --height 240 --width 432 --fp16
echo.

python inference_propainter.py ^
  --video inputs/video_completion/running_car.mp4 ^
  --mask inputs/video_completion/mask_square.png ^
  --height 240 ^
  --width 432 ^
  --fp16 > logs\quicktest.log 2>&1

set QT_EXIT=%errorlevel%

if %QT_EXIT%==0 (
    if exist results\running_car\inpaint_out.mp4 (
        echo =========================================================
        echo  [PASS] Quick Test 성공
        echo  결과: results\running_car\inpaint_out.mp4
        echo  로그: logs\quicktest.log
        echo =========================================================
        echo.
        echo  다음 단계:
        echo    1. smoke test 패키지를 이 폴더에 복사
        echo    2. run_smoke_test.bat 0  (Phase 0)
        echo    3. run_smoke_test.bat 1  (Phase 1)
        echo =========================================================
    ) else (
        echo [FAIL] 실행은 완료했으나 결과 파일이 없습니다.
        echo   로그 확인: type logs\quicktest.log
        goto :fail
    )
) else (
    echo [FAIL] Quick Test 실패 (exit code: %QT_EXIT%)
    echo.
    echo   로그 마지막 20줄:
    powershell -command "Get-Content 'logs\quicktest.log' -Tail 20" 2>nul
    echo.
    echo   오류 분류:
    echo     CUDA out of memory  → OOM (--height 176 --width 320 으로 재시도)
    echo     CUDA error          → 드라이버/torch 버전 문제
    echo     ModuleNotFoundError → pip install 누락
    echo     FileNotFoundError   → weights 또는 입력 경로 문제
    goto :fail
)

goto :end

:fail
echo.
echo =========================================================
echo  설치 중단. 위 오류 메시지를 총괄에게 보고하세요.
echo  보고할 것: 마지막 실행 명령, 콘솔 에러, dir 결과
echo =========================================================

:end
endlocal
pause
