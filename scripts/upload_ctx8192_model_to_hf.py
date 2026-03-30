#!/usr/bin/env python3
"""
Upload the local Qwen2.5-1.5B ctx8192 WebLLM artifacts to Hugging Face model hub.

Usage:
  HF_TOKEN=hf_xxx python3 scripts/upload_ctx8192_model_to_hf.py \
    --repo-id Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
import tempfile
from pathlib import Path


def eprint(msg: str) -> None:
    print(msg, file=sys.stderr)


def require_hf_lib() -> None:
    try:
        import huggingface_hub  # noqa: F401
    except Exception as exc:  # pragma: no cover - direct user-facing check
        eprint("Missing dependency: huggingface_hub")
        eprint("Install with: python3 -m pip install --upgrade huggingface_hub")
        raise SystemExit(2) from exc


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Upload Qwen2.5-1.5B ctx8192 artifacts to Hugging Face")
    parser.add_argument(
        "--repo-id",
        default="Ar5en1c/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-ctx8192",
        help="Target Hugging Face repo id (owner/name)",
    )
    parser.add_argument(
        "--model-dir",
        default="local-model-host/qwen2.5-1.5b-ctx8192-local/resolve/main",
        help="Directory containing mlc-chat-config.json + params_shard_*.bin + tokenizer files",
    )
    parser.add_argument(
        "--wasm-path",
        default="jobtracker-mlc-lab-worktree/.mlc-build/artifacts/Qwen2.5-1.5B-Instruct-q4f16_1-ctx8192_cs1024-webgpu-src-tvm.wasm",
        help="Compiled WebGPU wasm path",
    )
    parser.add_argument(
        "--wasm-name",
        default="Qwen2.5-1.5B-Instruct-q4f16_1-ctx8192_cs1024-webgpu.wasm",
        help="Output filename in HF repo for wasm",
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_TOKEN") or "",
        help="HF token (default from HF_TOKEN/HUGGINGFACE_TOKEN env)",
    )
    parser.add_argument(
        "--private",
        action="store_true",
        help="Create the repo as private (default public)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Prepare staging and print checks without uploading",
    )
    return parser.parse_args()


def resolve_token(cli_token: str) -> str:
    if cli_token:
        return cli_token
    candidates = []
    hf_home = os.environ.get("HF_HOME", "")
    if hf_home:
        candidates.append(Path(hf_home) / "token")
    candidates.append(Path.home() / ".cache" / "huggingface" / "token")
    for p in candidates:
        try:
            token = p.read_text(encoding="utf-8").strip()
            if token:
                return token
        except Exception:
            continue
    return ""


def validate_source_files(model_dir: Path, wasm_path: Path) -> None:
    required = [
        "mlc-chat-config.json",
        "tokenizer.json",
        "tensor-cache.json",
    ]
    missing = [name for name in required if not (model_dir / name).exists()]
    if missing:
        raise FileNotFoundError(f"Missing required files in model dir: {', '.join(missing)}")
    if not wasm_path.exists():
        raise FileNotFoundError(f"WASM not found: {wasm_path}")


def stage_upload_dir(model_dir: Path, wasm_path: Path, wasm_name: str) -> Path:
    temp_dir = Path(tempfile.mkdtemp(prefix="hf_ctx8192_upload_"))
    for item in model_dir.iterdir():
        if item.is_file():
            shutil.copy2(item, temp_dir / item.name)
    shutil.copy2(wasm_path, temp_dir / wasm_name)
    return temp_dir


def main() -> int:
    require_hf_lib()
    from huggingface_hub import HfApi

    args = parse_args()
    token = resolve_token(args.token)
    if not token and not args.dry_run:
        eprint("Missing token. Set HF_TOKEN or pass --token.")
        return 2

    model_dir = Path(args.model_dir).resolve()
    wasm_path = Path(args.wasm_path).resolve()

    try:
        validate_source_files(model_dir, wasm_path)
    except Exception as exc:
        eprint(f"Validation failed: {exc}")
        return 2

    stage_dir = stage_upload_dir(model_dir, wasm_path, args.wasm_name)
    print(f"Staging folder: {stage_dir}")
    print(f"Repo id: {args.repo_id}")
    print(f"Model dir: {model_dir}")
    print(f"WASM: {wasm_path} -> {args.wasm_name}")

    try:
        total_bytes = sum(p.stat().st_size for p in stage_dir.glob("*") if p.is_file())
        print(f"Payload size: {total_bytes / (1024 * 1024):.2f} MB")

        if args.dry_run:
            print("Dry run complete. No upload executed.")
            return 0

        api = HfApi(token=token)
        api.create_repo(repo_id=args.repo_id, repo_type="model", private=args.private, exist_ok=True)
        api.upload_folder(
            repo_id=args.repo_id,
            repo_type="model",
            folder_path=str(stage_dir),
            commit_message="Add Qwen2.5-1.5B q4f16_1 ctx8192 model + wasm",
        )
        print(f"Upload complete: https://huggingface.co/{args.repo_id}")
        print("Preset URLs for bench:")
        print(f"  model: https://huggingface.co/{args.repo_id}")
        print(
            "  model_lib: "
            f"https://huggingface.co/{args.repo_id}/resolve/main/{args.wasm_name}"
        )
        return 0
    finally:
        shutil.rmtree(stage_dir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
