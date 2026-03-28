# 8K Validation Protocol (No-Fluff)

This protocol is the official method for validating a custom 8k MLC/WebLLM model against a 4k baseline.

Scope:
- Model family: `Qwen2.5-1.5B-Instruct-q4f16_1-MLC`
- Runtime: WebLLM in browser (`bench.html`)
- Output: JSON export + generated markdown report

## Gate 0: Environment Disclosure (Required)

Record these fields in every report:
- Date/time (ISO)
- Browser + version
- OS + hardware
- `GPU`, `Vendor`, `Platform` from WebLLM Bench device panel
- WebLLM runtime URL

If any of these are missing, do not publish the run.

## Gate 1: Functional 8k Proof (>4k prompt)

Goal: prove the 8k model accepts context beyond 4096 while the 4k baseline cannot.

1. Use the **Compare** tab.
2. Set:
   - `Temp = 0`
   - `Max Tok = 128`
3. Use a retrieval prompt whose tokenized length is >4096 and <8192.
   - Recommended source file: `reports/ctx_gt4k_lt8k_retrieval_prompt.txt`
4. Compare:
   - Model A: custom 8k model
   - Model B: baseline 4k model

Pass criteria:
- 8k model completes and returns the required keys/values.
- 4k model fails with context overflow (`prompt tokens exceed context window`) or truncates context and fails retrieval.

## Gate 2: Performance Parity (<4k prompt)

Goal: confirm the 8k build is not materially slower at normal prompt sizes.

1. Use the **Bench** tab with A/B compare.
2. Set:
   - `Prompt Tokens = 1024`
   - `Max Output Tokens = 128`
   - `Iterations = 10`
   - `Temp = 0`
   - `Force full max tokens = ON`
3. Compare:
   - Model A: custom 8k model
   - Model B: baseline 4k model
4. Export JSON.

Pass criteria:
- Output token parity >= `0.95`
- Absolute decode TPS delta <= `10%`
- No repeated runtime/init failures

## Gate 3: Stability Run

Goal: verify no flaky init/runtime behavior.

1. Run Gate 2 three times (fresh tab each run).
2. Collect three exports.
3. Use medians for public claims.

Pass criteria:
- All three runs complete.
- No model init errors.
- Median decode delta still within +/-10%.

## Report Generation

Generate a strict markdown report from a compare export:

```bash
node scripts/generate_8k_validation_report.mjs --in /absolute/path/to/webllm-bench-<timestamp>.json
```

Default output:
- `reports/launch_8k_validation_YYYY-MM-DD.md`

## Memory Metrics Policy (Important)

Use these terms exactly:
- `VRAM Metadata`: value declared by model record (`vram_required_MB`)
- `JS Heap`: browser-observed JavaScript heap (`performance.memory`, when available)
- `GPU VRAM Live Usage`: **not available** from standard WebGPU browser APIs

Do not publish language that implies exact live GPU VRAM tracking from browser WebGPU.

## Public Claim Template

Use only if all gates pass:

- `[TESTED]` Custom 8k model loads and runs in WebLLM Bench.
- `[TESTED]` It handles >4k prompts where baseline 4k does not.
- `[TESTED]` At <=4k prompt workloads, decode speed is within parity threshold vs baseline.
- `[LIMITATION]` Browser WebGPU does not expose exact live GPU VRAM usage counters.
