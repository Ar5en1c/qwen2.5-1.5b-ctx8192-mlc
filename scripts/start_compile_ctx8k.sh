#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
EXP_DIR="$(cd "$THIS_DIR/.." && pwd)"
ROOT_DIR="${1:-$EXP_DIR/.mlc-build}"
MODEL_REPO="${2:-mlc-ai/Qwen2.5-1.5B-Instruct-q4f16_1-MLC}"
CTX="${3:-8192}"
PREFILL="${4:-1024}"
MODE="${5:-baseline}"

VENV_DIR="$ROOT_DIR/venv312_clean"
EMSDK_DIR="$ROOT_DIR/src/emsdk"
MLC_SRC_DIR="$ROOT_DIR/src/mlc-llm"
TVM_SRC_DIR="$MLC_SRC_DIR/3rdparty/tvm"
CACHE_DIR="$ROOT_DIR/cache"
MODEL_DIR="$ROOT_DIR/models/Qwen2.5-1.5B-Instruct-q4f16_1-MLC"
if [ "$MODE" = "turboint4" ]; then
  DIST_DIR="$ROOT_DIR/dist/Qwen2.5-1.5B-TurboQuant-int4-MLC-ctx${CTX}_cs${PREFILL}"
  OUT_WASM="$ROOT_DIR/artifacts/Qwen2.5-1.5B-TurboQuant-int4-ctx${CTX}_cs${PREFILL}-webgpu-src-tvm.wasm"
else
  DIST_DIR="$ROOT_DIR/dist/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx${CTX}_cs${PREFILL}"
  OUT_WASM="$ROOT_DIR/artifacts/Qwen2.5-1.5B-Instruct-q4f16_1-ctx${CTX}_cs${PREFILL}-webgpu-src-tvm.wasm"
fi
LOG_DIR="$EXP_DIR/reports/logs"
if [ "$MODE" = "turboint4" ]; then
  LOG_FILE="$LOG_DIR/compile_turboint4_ctx${CTX}_$(date +%Y%m%d_%H%M%S).log"
else
  LOG_FILE="$LOG_DIR/compile_ctx${CTX}_$(date +%Y%m%d_%H%M%S).log"
fi

mkdir -p "$ROOT_DIR/models" "$ROOT_DIR/dist" "$ROOT_DIR/artifacts" "$CACHE_DIR" "$LOG_DIR"

if [ ! -x "$VENV_DIR/bin/python" ]; then
  echo "Missing virtualenv at: $VENV_DIR" >&2
  echo "Run setup_mlc_webgpu_env_m1.sh first." >&2
  exit 1
fi

if [ ! -d "$MODEL_DIR/.git" ]; then
  GIT_LFS_SKIP_SMUDGE=1 git clone "https://huggingface.co/$MODEL_REPO" "$MODEL_DIR"
fi

FIRST_SHARD="$MODEL_DIR/params_shard_0.bin"
if [ -f "$FIRST_SHARD" ] && head -n 1 "$FIRST_SHARD" 2>/dev/null | grep -q 'https://git-lfs.github.com/spec/v1'; then
  echo "Detected Git LFS pointer shards in $MODEL_DIR; pulling real model weights..."
  git -C "$MODEL_DIR" lfs install --local >/dev/null
  git -C "$MODEL_DIR" lfs pull
fi

rm -rf "$DIST_DIR"
cp -R "$MODEL_DIR" "$DIST_DIR"

if [ "$MODE" = "turboint4" ]; then
  JQ_FILTER=".context_window_size=${CTX}
   | .model_config.context_window_size=${CTX}
   | .prefill_chunk_size=${PREFILL}
   | .model_config.prefill_chunk_size=${PREFILL}
   | .kv_cache_mode=\"turboquant_int4\"
   | .turboquant_enable_experimental=true
   | .turboquant_group_size=64
   | .turboquant_residual_bits=1
   | .model_config.kv_cache_mode=\"turboquant_int4\"
   | .model_config.turboquant_enable_experimental=true
   | .model_config.turboquant_group_size=64
   | .model_config.turboquant_residual_bits=1"
else
  JQ_FILTER=".context_window_size=${CTX}
   | .model_config.context_window_size=${CTX}
   | .prefill_chunk_size=${PREFILL}
   | .model_config.prefill_chunk_size=${PREFILL}"
fi

jq "$JQ_FILTER" "$DIST_DIR/mlc-chat-config.json" > "$DIST_DIR/mlc-chat-config.json.tmp"
mv "$DIST_DIR/mlc-chat-config.json.tmp" "$DIST_DIR/mlc-chat-config.json"

export ROOT_DIR
PYTHON_BIN="$VENV_DIR/bin/python"

# Apply deterministic local compatibility patches needed for this macOS + emsdk toolchain.
"$PYTHON_BIN" - <<'PY'
import os
from pathlib import Path

root = Path(os.environ["ROOT_DIR"]) / "src/mlc-llm/3rdparty/tvm"

def ensure_contains(path: Path, needle: str, replacement: str) -> None:
    text = path.read_text()
    if replacement in text:
        return
    if needle not in text:
        raise RuntimeError(f"Patch needle not found in {path}: {needle[:80]!r}")
    path.write_text(text.replace(needle, replacement))

# Python object-slot compatibility patches
ensure_contains(
    root / "python/tvm/relax/block_builder.py",
    "_stack = []\n",
    "_stack = []\n    __slots__ = [\"_func_stack\"]\n",
)
ensure_contains(
    root / "python/tvm/ir/transform.py",
    "    class PyModulePass(ModulePass):\n        \"\"\"Internal wrapper class to create a class instance.\"\"\"\n",
    "    class PyModulePass(ModulePass):\n        \"\"\"Internal wrapper class to create a class instance.\"\"\"\n        __slots__ = [\"_inst\"]\n",
)
ensure_contains(
    root / "python/tvm/runtime/support.py",
    "        _cls = cls\n        _type = \"TVMDerivedObject\"\n",
    "        _cls = cls\n        _type = \"TVMDerivedObject\"\n        __slots__ = [\"_inst\"]\n",
)
support_path = root / "python/tvm/runtime/support.py"
support_text = support_path.read_text()
support_block = (
    "            try:\n"
    "                self._inst._outer = weakref.ref(self)\n"
    "            except TypeError:\n"
    "                self._inst._outer = lambda: self\n"
)
if support_block not in support_text:
    if "            self._inst._outer = weakref.ref(self)\n" in support_text:
        support_text = support_text.replace(
            "            self._inst._outer = weakref.ref(self)\n",
            support_block,
        )
    else:
        raise RuntimeError("Cannot patch weakref fallback in runtime/support.py")
# Cleanup accidental duplicate/nested patch patterns from previous runs.
support_text = support_text.replace(
    "            try:\n                try:\n",
    "            try:\n",
)
support_text = support_text.replace(
    "            except TypeError:\n                self._inst._outer = lambda: self\n            except TypeError:\n                self._inst._outer = lambda: self\n",
    "            except TypeError:\n                self._inst._outer = lambda: self\n",
)
support_path.write_text(support_text)

# Ensure packed-call lowering runs for both host and device finalization passes.
pipeline_path = root / "python/tvm/tir/pipeline.py"
pipeline_text = pipeline_path.read_text()
if "tir.transform.LowerTVMBuiltin(),\n        tir.transform.LowerWarpMemory()," not in pipeline_text:
    ensure_contains(
        pipeline_path,
        "    device_pass_list = [\n        tir.transform.LowerWarpMemory(),\n        tir.transform.Simplify(),\n        tir.transform.LowerCustomDatatypes(),\n        tir.transform.LowerIntrin(),\n    ]\n",
        "    device_pass_list = [\n        tir.transform.LowerTVMBuiltin(),\n        tir.transform.LowerWarpMemory(),\n        tir.transform.Simplify(),\n        tir.transform.LowerCustomDatatypes(),\n        tir.transform.LowerIntrin(),\n        tir.transform.LowerTVMBuiltin(),\n    ]\n",
    )
if "tir.transform.LowerIntrin(),\n        # Some targets still surface tvm_call_packed after LowerIntrin." not in pipeline_text:
    ensure_contains(
        pipeline_path,
        "    host_pass_list = [\n        tir.transform.LowerTVMBuiltin(),\n        tir.transform.LowerCustomDatatypes(),\n        tir.transform.LowerIntrin(),\n    ]\n",
        "    host_pass_list = [\n        tir.transform.LowerTVMBuiltin(),\n        tir.transform.LowerCustomDatatypes(),\n        tir.transform.LowerIntrin(),\n        # Some targets still surface tvm_call_packed after LowerIntrin.\n        # Run builtin lowering again to avoid unresolved intrinsics at LLVM codegen.\n        tir.transform.LowerTVMBuiltin(),\n    ]\n",
    )

# wasm-opt in emsdk 3.1.56 does not recognize --enable-bulk-memory-opt at O3 path.
ensure_contains(
    root / "python/tvm/contrib/emcc.py",
    "    cmd += [\"-O3\"]\n",
    "    # Local fallback for toolchain compatibility: avoid wasm-opt feature-flag mismatch\n    # in older binaryen builds bundled with some emsdk revisions.\n    cmd += [\"-O0\"]\n",
)
PY

source "$EMSDK_DIR/emsdk_env.sh"
export MLC_LLM_HOME="$CACHE_DIR"
export MLC_LLM_SOURCE_DIR="$MLC_SRC_DIR"
if [ -d "$VENV_DIR/lib/python3.12/site-packages/mlc_llm" ]; then
  export MLC_LIBRARY_PATH="$VENV_DIR/lib/python3.12/site-packages/mlc_llm"
fi
export TVM_SOURCE_DIR="$TVM_SRC_DIR"
TVM_BUILD_DIR_CANDIDATE="${TVM_BUILD_DIR:-$TVM_SRC_DIR/build_local}"
if [ ! -d "$TVM_BUILD_DIR_CANDIDATE" ]; then
  TVM_BUILD_DIR_CANDIDATE="$TVM_SRC_DIR/build"
fi
export TVM_LIBRARY_PATH="$TVM_BUILD_DIR_CANDIDATE"
export PYTHONPATH="$MLC_SRC_DIR/python:$TVM_SRC_DIR/python:${PYTHONPATH:-}"
echo "[compile sanity] TVM_LIBRARY_PATH=$TVM_LIBRARY_PATH"

"$PYTHON_BIN" - <<'PY'
import inspect
import mlc_llm.model.qwen2.qwen2_model as qwen2_model

src = inspect.getsource(qwen2_model.QWen2LMHeadModel.create_paged_kv_cache)
if "turboquant_kv_mode" not in src:
    raise RuntimeError(
        "Compile environment is not using patched mlc_llm source "
        "(missing turboquant_kv_mode in create_paged_kv_cache)."
    )
print("[compile sanity] Using patched mlc_llm qwen2_model with turboquant plumbing.")
PY

set +e
"$PYTHON_BIN" -m mlc_llm compile \
  "$DIST_DIR/mlc-chat-config.json" \
  --device webgpu \
  -o "$OUT_WASM" 2>&1 | tee "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
set -e

if [ "$EXIT_CODE" -eq 0 ]; then
  echo "Compile succeeded: $OUT_WASM"
  du -h "$OUT_WASM"
else
  echo "Compile failed. See log: $LOG_FILE" >&2
  exit "$EXIT_CODE"
fi
