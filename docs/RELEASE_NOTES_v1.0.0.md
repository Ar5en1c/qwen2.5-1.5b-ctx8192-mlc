# Qwen2.5-1.5B ctx8192 MLC Workflow v1.0.0

## What this release includes

- Reproducible compile/runbook workflow for `Qwen2.5-1.5B` at `ctx8192`
- Validation protocol and report generators
- Hosted Hugging Face one-click integration guide for WebLLM Bench
- Launch validation artifacts and claim-safe summary

## Validation summary (measured)

Primary aggregate source:
- `reports/launch_8k_batch_validation_2026-03-28.md`

Fixed profile used for aggregate parity:
- `promptTokens=1024`
- `maxTokens=128`
- `iterations=10`

Included 8k-vs-4k runs: `8`

Median deltas (8k custom vs 4k baseline):
- Decode TPS: `+0.11%`
- Throughput: `-0.06%`
- Latency: `+0.09%`
- Token parity: `1.000`

Range:
- Decode delta: `-0.53% .. +1.58%`
- Latency delta: `-1.33% .. +0.48%`

Latest long-output stress profile (`1024/512/5`, force-full):
- Throughput delta: `-1.96%`
- Latency delta: `+1.94%`
- Decode delta: `-1.98%`
- TTFT delta: `+0.63%`

Functional gate:
- 8k build handles >4k retrieval prompts
- 4k baseline overflows at `5813` prompt tokens (`ctx=4096`)

## Hosted artifacts

- Model repo:
  - `https://huggingface.co/Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192`
- WebGPU wasm:
  - `https://huggingface.co/Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192/resolve/main/Qwen2.5-1.5B-Instruct-q4f16_1-ctx8192_cs1024-webgpu.wasm`

## Limitation statement

- Browser WebGPU does not expose exact live GPU VRAM telemetry; VRAM values are model metadata/proxy signals.

## Repro

```bash
npm run report:8k:batch
```

Per-export report:

```bash
npm run report:8k:validation -- --in /absolute/path/to/webllm-bench-<timestamp>.json
```
