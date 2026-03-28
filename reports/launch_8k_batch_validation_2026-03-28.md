# 8K Batch Validation Report

Generated: 2026-03-28T23:51:18.706Z
Source folder: `reports/`

## Included Runs

- Included 8k-vs-4k exports: **8**
- Browser families detected in JSON: Chrome-family, Safari

| Export | GeneratedAt | Browser | Config (prompt/max/iters) | Decode Δ | Throughput Δ | Latency Δ | Token Parity |
|---|---|---|---|---:|---:|---:|---:|
| `webllm-bench-2026-03-28T203438865Z.json` | 2026-03-28T20:32:52.387Z | Chrome-family | 1024/128/10 | +0.12% | +0.15% | -0.12% | 1.000 |
| `webllm-bench-2026-03-28T204320338Z.json` | 2026-03-28T20:38:23.398Z | Chrome-family | 1024/128/10 | +1.56% | +1.29% | -1.27% | 1.000 |
| `webllm-bench-2026-03-28T213858736Z.json` | 2026-03-28T21:38:39.772Z | Chrome-family | 1024/128/10 | +0.10% | -0.34% | +0.43% | 1.000 |
| `webllm-bench-2026-03-28T214344099Z.json` | 2026-03-28T21:42:49.969Z | Chrome-family | 1024/128/10 | +1.58% | +1.35% | -1.33% | 1.000 |
| `webllm-bench-2026-03-28T221747842Z.json` | 2026-03-28T22:12:53.059Z | Chrome-family | 1024/128/10 | -0.17% | -0.47% | +0.48% | 1.000 |
| `webllm-bench-2026-03-28T222207852Z.json` | 2026-03-28T22:21:40.256Z | Chrome-family | 1024/128/10 | -0.03% | -0.38% | +0.44% | 1.000 |
| `webllm-bench-2026-03-28T224607779Z.json` | 2026-03-28T22:45:37.117Z | Safari | 1024/128/10 | -0.53% | -0.26% | +0.30% | 1.000 |
| `webllm-bench-2026-03-28T225258569Z.json` | 2026-03-28T22:51:40.365Z | Safari | 1024/128/10 | +0.80% | +0.51% | -0.51% | 1.000 |

## Aggregate Summary (Median Across Included Runs)

- Decode TPS delta (8k vs 4k): **+0.11%**
- Throughput delta: **-0.06%**
- Latency delta: **+0.09%**
- Prefill TPS delta: **+0.11%**
- TTFT delta: **-0.10%**
- ms/token delta: **+0.09%**
- Token parity median: **1.000**

Range checks:
- Decode delta range: -0.53% .. +1.58%
- Latency delta range: -1.33% .. +0.48%

## Gate Results

- PASS: High-context candidate has ctx >= 8192 in all included runs.
- PASS: Output token parity >= 0.95 in all included runs.
- PASS: |Decode delta| <= 10% in all included runs.
- PASS: iterations >= 5 in all included runs.

Final verdict: **PASS**

## Claim-Safe Statement

- [TESTED] Across included exports, the 8k custom build remains within parity band versus the 4k baseline on this benchmark profile.
- [TESTED] Functional >4k retrieval evidence is recorded separately in session logs (4k overflow at 5813 tokens).
- [LIMITATION] Browser WebGPU does not expose exact live GPU VRAM usage counters; use model metadata and JS heap as proxy signals only.

## Excluded Exports

- `webllm-bench-2026-03-28T205156281Z.json`: not an 8k-vs-4k pair

