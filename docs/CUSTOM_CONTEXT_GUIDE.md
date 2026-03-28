# Custom Context Window Guide for MLC/WebLLM Models

This guide shows how to compile any MLC model at a custom context window size (e.g., 4k → 8k → 16k → 32k) for WebGPU inference.

**Tested with:** Qwen2.5-1.5B-Instruct-q4f16_1-MLC at 8192 context.

## Prerequisites

- macOS with Apple Silicon (M1/M2/M3) or Linux with CUDA
- Python 3.12
- Git with LFS
- ~15 GB disk space for build tools + model weights
- Node.js 18+ (for model record generation)

## 1. Set up the MLC build environment

```bash
# Clone MLC-LLM with submodules
git clone --recursive https://github.com/mlc-ai/mlc-llm.git mlc-llm-src
cd mlc-llm-src

# Create isolated Python virtualenv
python3.12 -m venv venv
source venv/bin/activate
pip install --upgrade pip

# Install MLC-LLM from source
pip install -e ".[dev]"

# Install Emscripten SDK (required for WebGPU/WASM)
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source emsdk_env.sh
cd ..
```

## 2. Download the base model

```bash
mkdir -p models
GIT_LFS_SKIP_SMUDGE=1 git clone \
  https://huggingface.co/mlc-ai/Qwen2.5-1.5B-Instruct-q4f16_1-MLC \
  models/Qwen2.5-1.5B-Instruct-q4f16_1-MLC

cd models/Qwen2.5-1.5B-Instruct-q4f16_1-MLC
git lfs install --local
git lfs pull
cd ../..
```

## 3. Create the custom context distribution

```bash
CTX=8192        # target context window
PREFILL=1024    # prefill chunk size

# Copy base model
DIST_DIR="dist/Qwen2.5-1.5B-ctx${CTX}"
cp -R models/Qwen2.5-1.5B-Instruct-q4f16_1-MLC "$DIST_DIR"

# Patch the config
jq ".context_window_size=${CTX}
    | .model_config.context_window_size=${CTX}
    | .prefill_chunk_size=${PREFILL}
    | .model_config.prefill_chunk_size=${PREFILL}" \
  "$DIST_DIR/mlc-chat-config.json" > "$DIST_DIR/mlc-chat-config.json.tmp"
mv "$DIST_DIR/mlc-chat-config.json.tmp" "$DIST_DIR/mlc-chat-config.json"
```

## 4. Compile for WebGPU

```bash
python -m mlc_llm compile \
  "$DIST_DIR/mlc-chat-config.json" \
  --device webgpu \
  -o "artifacts/Qwen2.5-1.5B-ctx${CTX}-webgpu.wasm"
```

Compilation takes 10–30 minutes depending on hardware. The output WASM file is your custom model library.

## 5. Generate a WebLLM model record

Create a model record JSON that tells WebLLM how to load your custom build:

```json
{
  "model": "https://huggingface.co/mlc-ai/Qwen2.5-1.5B-Instruct-q4f16_1-MLC",
  "model_id": "Qwen2.5-1.5B-Instruct-ctx8192-custom",
  "model_lib": "http://localhost:8765/artifacts/Qwen2.5-1.5B-ctx8192-webgpu.wasm",
  "overrides": {
    "context_window_size": 8192,
    "prefill_chunk_size": 1024
  }
}
```

Serve the artifacts directory locally:

```bash
npx -y http-server ./artifacts -p 8765 --cors
```

## 6. Load in WebLLM

```javascript
import { CreateMLCEngine } from "@mlc-ai/web-llm";

const engine = await CreateMLCEngine("Qwen2.5-1.5B-Instruct-ctx8192-custom", {
  appConfig: {
    model_list: [YOUR_MODEL_RECORD],
    useIndexedDBCache: false,
  },
});
```

## 7. Validate against baseline

Use the benchmark tool (`bench.html`) to compare your custom build against the prebuilt 4k model:

1. Run a benchmark on the prebuilt `Qwen2.5-1.5B-Instruct-q4f16_1-MLC`
2. Run the same benchmark on your custom 8k build
3. Compare TPS, latency, and output quality

**Expected results:** The 8k build should have similar decode TPS to the 4k baseline. Prefill may be slightly slower due to the larger context window computation.

## Known Gotchas

### ABI argument count mismatch
Custom-compiled WASM may expose more function arguments than the prebuilt WebLLM runtime expects. If you see runtime crashes about constructor arguments, the WASM ABI has diverged. See `webllm-lab/app.js` for the ABI shimming approach used in this project.

### Prefill chunk size
Setting `prefill_chunk_size` larger than what fits in device VRAM causes OOM. Start with 1024 and increase only after confirming stability.

### WASM optimization level
The compile script uses `-O0` by default for compatibility with some Emscripten toolchains. For production, rebuild with `-O2` for ~10-20% faster inference (requires testing with your specific emsdk version).

### Stale IndexedDB cache
WebLLM caches model shards in IndexedDB. When switching between custom and prebuilt models, set `useIndexedDBCache: false` to avoid loading stale cached shards from a different build.
