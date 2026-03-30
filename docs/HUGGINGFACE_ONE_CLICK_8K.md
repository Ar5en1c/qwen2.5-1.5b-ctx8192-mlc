# Hugging Face One-Click 8k Preset

This project now supports a public one-click button in the UI:

- `⚡ Add Qwen2.5 8k Preset (Hosted)`

It injects a hosted custom model record and adds it to the registry automatically.

## Default Hosted Target

The preset is wired to:

- Model root: `https://huggingface.co/Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192`
- Model lib: `https://huggingface.co/Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192/resolve/main/Qwen2.5-1.5B-Instruct-q4f16_1-ctx8192_cs1024-webgpu.wasm`

## Upload the 8k Artifacts

1. Create a local virtualenv and install uploader dependency:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade huggingface_hub
```

2. Set token (write access to your model repo):

```bash
export HF_TOKEN=hf_xxx
```

3. Dry-run validation:

```bash
source .venv/bin/activate
python scripts/upload_ctx8192_model_to_hf.py --dry-run
```

4. Upload:

```bash
source .venv/bin/activate
python scripts/upload_ctx8192_model_to_hf.py \
  --repo-id Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192
```

5. On Hugging Face, set the model repo visibility to **Public** (required for anonymous browser users).

## If Upload Is Interrupted (Recommended Recovery)

If you press `Ctrl+C` during upload, no problem. Just rerun with the resumable CLI flow:

```bash
source .venv/bin/activate
export HF_HUB_DISABLE_XET=1

# Upload model folder (resumable)
hf upload-large-folder \
  Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192 \
  local-model-host/qwen2.5-1.5b-ctx8192-local/resolve/main \
  --repo-type model \
  --num-workers 4

# Upload wasm artifact
hf upload \
  Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192 \
  jobtracker-mlc-lab-worktree/.mlc-build/artifacts/Qwen2.5-1.5B-Instruct-q4f16_1-ctx8192_cs1024-webgpu-src-tvm.wasm \
  Qwen2.5-1.5B-Instruct-q4f16_1-ctx8192_cs1024-webgpu.wasm \
  --repo-type model
```

Verify with:

```bash
curl -I https://huggingface.co/Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192/resolve/main/mlc-chat-config.json
curl -I https://huggingface.co/Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192/resolve/main/Qwen2.5-1.5B-Instruct-q4f16_1-ctx8192_cs1024-webgpu.wasm
```

Both should return `HTTP/2 200`.

## If You Use a Different HF Repo

You can override the preset without editing JS by defining `window.WEBLLM_BENCH_PRESETS` before loading `bench.js`.

Add this near the bottom of `bench.html` (before `<script src="bench.js"></script>`):

```html
<script>
  window.WEBLLM_BENCH_PRESETS = {
    qwen25_15b_ctx8192_hf: {
      model: "https://huggingface.co/<owner>/<repo>",
      model_id: "Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192-<owner>",
      model_lib: "https://huggingface.co/<owner>/<repo>/resolve/main/Qwen2.5-1.5B-Instruct-q4f16_1-ctx8192_cs1024-webgpu.wasm",
      overrides: { context_window_size: 8192, prefill_chunk_size: 1024 },
      vram_required_MB: 2000
    }
  };
</script>
```

## User Experience

After upload, users can:

1. Open the app.
2. Expand `Add Custom Model`.
3. Click `⚡ Add Qwen2.5 8k Preset (Hosted)`.
4. Use that model directly in Bench/Chat/Compare.
