# Contributing

## Ground Rules

- Keep this experiment scoped to `Qwen2.5-1.5B-Instruct` unless scope is explicitly expanded.
- Do not claim production-quality TurboQuant support until runtime kernels and fallback tests are complete.
- Keep changes focused and reviewable.

## Recommended Workflow

1. Run local baseline before changing runtime behavior:
   - `npm run all:full`
   - `npm run test`
2. Implement one small change at a time.
3. Re-run baseline scripts and include before/after outputs.
4. If touching runtime integration, update `mlc-fork/` notes and checkpoints.

## Pull Request Checklist

- [ ] Change is scoped to this experiment directory.
- [ ] `npm run test` passes.
- [ ] Reports regenerate cleanly.
- [ ] No hardcoded local absolute paths in committed docs/config.
- [ ] Fallback behavior is documented for runtime changes.

## Bug Reports

Please include:

- Hardware/OS/browser details.
- Exact command run.
- Relevant log snippet.
- Whether issue reproduces on clean run.
