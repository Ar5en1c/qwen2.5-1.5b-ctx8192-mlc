#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
EXP_DIR="$(cd "$THIS_DIR/.." && pwd)"
ROOT_DIR="${1:-$EXP_DIR/.mlc-build}"
SRC_DIR="$ROOT_DIR/src"
VENV_DIR="$ROOT_DIR/venv312_clean"
EMSDK_DIR="$SRC_DIR/emsdk"
MLC_SRC_DIR="$SRC_DIR/mlc-llm"
TVM_SRC_DIR="$MLC_SRC_DIR/3rdparty/tvm"
CACHE_DIR="$ROOT_DIR/cache"

mkdir -p "$ROOT_DIR" "$SRC_DIR" "$CACHE_DIR" "$ROOT_DIR/artifacts" "$ROOT_DIR/dist" "$ROOT_DIR/models"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required. Install brew first." >&2
  exit 1
fi

brew install python@3.12 cmake rust git-lfs llvm@21 ninja

if [ ! -d "$MLC_SRC_DIR/.git" ]; then
  git clone --recursive https://github.com/mlc-ai/mlc-llm.git "$MLC_SRC_DIR"
fi

if [ ! -d "$EMSDK_DIR/.git" ]; then
  git clone https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
fi

cd "$EMSDK_DIR"
./emsdk install 3.1.56
./emsdk activate 3.1.56

/opt/homebrew/bin/python3.12 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
python -m pip install -U pip
python -m pip install --pre -U -f https://mlc.ai/wheels mlc-llm-nightly-cpu mlc-ai-nightly-cpu

source "$EMSDK_DIR/emsdk_env.sh"
export TVM_SOURCE_DIR="$TVM_SRC_DIR"
cd "$MLC_SRC_DIR"
./web/prep_emcc_deps.sh

LLVM_CONFIG="/opt/homebrew/opt/llvm@21/bin/llvm-config"
if [ ! -x "$LLVM_CONFIG" ]; then
  echo "Missing llvm-config at $LLVM_CONFIG" >&2
  exit 1
fi

cd "$TVM_SRC_DIR"
if [ ! -f build/CMakeCache.txt ]; then
  cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_LLVM="$LLVM_CONFIG" \
    -DUSE_METAL=OFF
fi
cmake --build build -j 8

cat <<MSG
Environment bootstrapped.

Build root: $ROOT_DIR
Venv:       $VENV_DIR
MLC source: $MLC_SRC_DIR
Emsdk:      $EMSDK_DIR

Next:
  scripts/start_compile_ctx8k.sh
MSG
