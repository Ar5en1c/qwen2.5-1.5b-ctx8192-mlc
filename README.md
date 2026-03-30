# Qwen2.5-1.5B ctx8192 MLC Workflow (OSS Package)

This repo package contains the reproducible workflow and validation artifacts for compiling/testing a ctx8192 build.

## What is included

- Compile/runbook docs
- Validation protocol
- Report generators
- Latest batch validation report

## Validation report

- reports/launch_8k_batch_validation_2026-03-28.md
- docs/RELEASE_NOTES_v1.0.0.md

## Hosted model artifacts

- https://huggingface.co/Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192
- https://huggingface.co/Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192/resolve/main/Qwen2.5-1.5B-Instruct-q4f16_1-ctx8192_cs1024-webgpu.wasm

## Companion app

- WebLLM Bench (live): https://ar5en1c.github.io/webllm-bench/bench.html
- WebLLM Bench repo: https://github.com/Ar5en1c/webllm-bench

## Repro

```bash
npm run report:8k:batch
```
