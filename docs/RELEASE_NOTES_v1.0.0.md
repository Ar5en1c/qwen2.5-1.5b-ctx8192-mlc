# WebLLM Bench v1.0.0

## What this release includes

- Browser-native local LLM toolkit:
  - Benchmark
  - Chat
  - Side-by-side compare
  - Best-model sweep
  - Community baseline import/export
- Custom model support for MLC/WebLLM artifacts
- One-click hosted preset for Qwen2.5-1.5B ctx8192
- Reproducible 8k context validation protocol and report generators

## 8k validation result (Qwen2.5-1.5B, measured)

Source:
- `reports/launch_8k_batch_validation_2026-03-28.md`

Profile used for all included parity runs:
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

Browser families represented in exports:
- `Chrome-family, Safari`

Functional context gate:
- 8k model handles a >4k retrieval prompt.
- 4k baseline overflows at `5813` prompt tokens (`context window size: 4096`).

## Claim-safe summary

- [TESTED] Custom ctx8192 model is stable and remains in parity band vs the official 4k baseline on the fixed benchmark profile above.
- [TESTED] The ctx8192 model passes functional >4k prompt handling where 4k fails by context limit.
- [LIMITATION] Browser WebGPU does not expose exact live GPU VRAM usage counters; VRAM values are model metadata and JS heap proxies.

## Repro steps

```bash
npm run test
npm run report:8k:batch
npm run launch:draft
```

Per-export report:

```bash
npm run report:8k:validation -- --in /absolute/path/to/webllm-bench-<timestamp>.json
```

Hosted preset artifacts:
- `https://huggingface.co/Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192`
- `https://huggingface.co/Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192/resolve/main/Qwen2.5-1.5B-Instruct-q4f16_1-ctx8192_cs1024-webgpu.wasm`

## Notes

- Excluded from 8k-vs-4k aggregate:
  - `reports/webllm-bench-2026-03-28T205156281Z.json` (not an 8k-vs-4k pair).
