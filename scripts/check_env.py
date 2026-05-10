#!/usr/bin/env python3
"""
check_env.py
프로젝트: 원본 지우개
목적: ProPainter 실행 전 환경 전체 자동 점검
버전: v1.0 | 기준일: 2026-05-10

사용법:
  python scripts/check_env.py

모든 체크 통과 시 → Smoke Test 실행 가능
"""

import sys
import os
import subprocess

PASS = "✅ PASS"
FAIL = "❌ FAIL"
WARN = "⚠️  WARN"
INFO = "ℹ️  INFO"

results = []


def check(name, condition, msg_pass, msg_fail, level="required"):
    icon = PASS if condition else (FAIL if level == "required" else WARN)
    msg = msg_pass if condition else msg_fail
    print(f"  {icon} [{name}] {msg}")
    results.append({"name": name, "ok": condition, "level": level})
    return condition


print("=" * 65)
print("  원본 지우개 - 환경 점검 스크립트")
print("  ProPainter 실행 가능 여부 자동 판정")
print("=" * 65)
print()

# ─── 1. Python 버전 ──────────────────────────────────────────
print("[1] Python 버전")
major, minor = sys.version_info.major, sys.version_info.minor
py_ok = (major == 3 and minor >= 8)
check("Python", py_ok,
      f"Python {major}.{minor} (OK)",
      f"Python {major}.{minor} - 3.8 이상 필요. conda create -n propainter python=3.8")
print()

# ─── 2. PyTorch / CUDA ───────────────────────────────────────
print("[2] PyTorch & CUDA")
try:
    import torch
    torch_version = torch.__version__
    cuda_available = torch.cuda.is_available()

    check("torch_import", True, f"torch {torch_version}", "")
    check("cuda_available", cuda_available,
          "CUDA 사용 가능",
          "CUDA 불가 → GPU 드라이버 또는 CUDA 버전 확인")

    if cuda_available:
        gpu_name = torch.cuda.get_device_name(0)
        vram_gb = torch.cuda.get_device_properties(0).total_memory / 1024**3
        cuda_ver = torch.version.cuda

        check("gpu_name", "1080" in gpu_name or True,
              f"GPU: {gpu_name}",
              f"GPU: {gpu_name} (예상과 다를 수 있음)", level="info")
        check("vram", vram_gb >= 6,
              f"VRAM: {vram_gb:.1f}GB (6GB 이상 OK)",
              f"VRAM: {vram_gb:.1f}GB - 6GB 미만, OOM 위험")
        check("cuda_version", cuda_ver is not None,
              f"CUDA 버전: {cuda_ver}",
              "CUDA 버전 확인 불가")

        # fp16 지원 확인 (GTX 1080 지원)
        try:
            test_tensor = torch.zeros(1).half().cuda()
            fp16_ok = True
        except Exception:
            fp16_ok = False
        check("fp16", fp16_ok,
              "fp16 (half precision) 지원 확인",
              "fp16 불가 → --fp16 옵션 제거 필요", level="important")

except ImportError:
    check("torch_import", False, "",
          "torch 없음 → pip install torch==2.0.1+cu118 torchvision==0.15.2+cu118 --index-url https://download.pytorch.org/whl/cu118")
print()

# ─── 3. 필수 패키지 ───────────────────────────────────────────
print("[3] 필수 패키지 임포트")
packages = [
    ("cv2", "opencv-python"),
    ("einops", "einops"),
    ("timm", "timm"),
    ("scipy", "scipy"),
    ("PIL", "Pillow"),
    ("numpy", "numpy"),
    ("requests", "requests"),
    ("yaml", "pyyaml"),
    ("addict", "addict"),
    ("imageio", "imageio"),
]

for pkg_import, pkg_install in packages:
    try:
        __import__(pkg_import)
        check(pkg_import, True, f"{pkg_install} 임포트 OK", "")
    except ImportError:
        check(pkg_import, False, "",
              f"{pkg_install} 없음 → pip install {pkg_install}")

# av 패키지 별도 처리
try:
    import av
    check("av", True, "av (PyAV) 임포트 OK", "")
except ImportError:
    check("av", False, "",
          "av 없음 → conda install av -c conda-forge")
print()

# ─── 4. Weights 파일 ─────────────────────────────────────────
print("[4] ProPainter Weights 파일")
weight_files = [
    ("weights/ProPainter.pth", "~280MB"),
    ("weights/recurrent_flow_completion.pth", "~50MB"),
    ("weights/raft-things.pth", "~21MB"),
]

weights_ok = True
for wf, expected_size in weight_files:
    exists = os.path.isfile(wf)
    if exists:
        size_mb = os.path.getsize(wf) / 1024 / 1024
        check(wf, True, f"{wf} ({size_mb:.0f}MB)", "")
    else:
        check(wf, False, "",
              f"{wf} 없음 ({expected_size}) - 첫 실행 시 자동 다운로드 또는 수동 다운로드",
              level="important")
        weights_ok = False
print()

# ─── 5. 입력 파일 (Phase 0 공식 샘플) ────────────────────────
print("[5] Phase 0 공식 샘플 입력")
sample_video = "inputs/video_completion/running_car.mp4"
sample_mask = "inputs/video_completion/mask_square.png"

check("sample_video", os.path.isfile(sample_video),
      f"공식 샘플 영상: {sample_video}",
      f"없음: {sample_video} - ProPainter 저장소 루트에서 실행 확인")
check("sample_mask", os.path.isfile(sample_mask),
      f"공식 샘플 마스크: {sample_mask}",
      f"없음: {sample_mask}")
print()

# ─── 6. ffmpeg ───────────────────────────────────────────────
print("[6] FFmpeg")
try:
    import imageio_ffmpeg
    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
    check("ffmpeg", bool(ffmpeg_exe),
          f"imageio-ffmpeg 내장 ffmpeg: {ffmpeg_exe}",
          "ffmpeg 없음")
except Exception:
    # 시스템 ffmpeg 확인
    result = subprocess.run(["ffmpeg", "-version"],
                            capture_output=True, text=True)
    ffmpeg_sys = result.returncode == 0
    check("ffmpeg", ffmpeg_sys,
          "시스템 ffmpeg 사용 가능",
          "ffmpeg 없음 → conda install ffmpeg -c conda-forge", level="warn")
print()

# ─── 최종 판정 ───────────────────────────────────────────────
required_fails = [r for r in results if not r["ok"] and r["level"] == "required"]
important_fails = [r for r in results if not r["ok"] and r["level"] == "important"]
all_pass = len(required_fails) == 0

print("=" * 65)
print("  최종 판정")
print("=" * 65)

if all_pass:
    if len(important_fails) == 0:
        print(f"  ✅ READY - 모든 체크 통과. Smoke Test 실행 가능!")
        print()
        print("  실행 명령:")
        print("    bash scripts/run_smoke_test.sh 0")
        print("    또는: scripts\\run_smoke_test.bat 0")
    else:
        print(f"  ⚠️  READY (경고 {len(important_fails)}개) - Smoke Test 실행 가능하나 주의 필요")
        for r in important_fails:
            print(f"    - {r['name']}: 확인 권장")
else:
    print(f"  ❌ NOT READY - {len(required_fails)}개 필수 항목 미통과")
    print()
    print("  해결 필요:")
    for r in required_fails:
        print(f"    - {r['name']}: docs/environment_setup.md 참조")

print()
print(f"  통과: {len([r for r in results if r['ok']])}/{len(results)}")
print("=" * 65)

sys.exit(0 if all_pass else 1)
