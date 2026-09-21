#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the MeowKit firmware.
# Prepares three verifiable workflows: native CMake/CTest host tests, the
# desktop LVGL UI simulator, and the PlatformIO ESP32-S3 firmware build.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Installing system packages"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
# build-essential/cmake/gcc pull the GNU toolchain (the default cc/c++ is Clang,
# which cannot find libstdc++ here); libsdl2-dev backs the UI simulator; ninja
# is the generator the test docs use; python3-venv is required for the venv.
sudo apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build pkg-config git \
  libsdl2-dev python3-venv python3-pip

echo "==> Initializing pinned submodules (firmware build dependencies)"
git submodule update --init --recursive

echo "==> Creating Python venv with pinned PlatformIO"
if [ ! -x .venv/bin/python ]; then
  python3 -m venv .venv
fi
.venv/bin/python -m pip install --quiet --upgrade pip
.venv/bin/python -m pip install --quiet 'platformio==6.1.19'

echo "==> Warming the ESP32 platform toolchain cache"
# Pre-fetch so the first firmware build does not pay the download cost.
.venv/bin/python -m platformio platform install 'espressif32@6.0.1' >/dev/null

echo "==> Pre-configuring native host tests (GCC toolchain)"
# The default cc/c++ symlinks are Clang 18, which fails to link libstdc++ in
# this image, so pin GCC to match the ubuntu-24.04 CI runner.
cmake -S test/lua_apps -B build/native -G Ninja -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++

echo "==> Environment ready"
