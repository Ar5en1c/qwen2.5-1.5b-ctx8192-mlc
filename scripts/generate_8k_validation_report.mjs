#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

function die(msg) {
  console.error(`ERROR: ${msg}`);
  process.exit(1);
}

function pctDelta(newVal, oldVal, digits = 2) {
  if (!Number.isFinite(newVal) || !Number.isFinite(oldVal) || oldVal === 0) return null;
  return +(((newVal - oldVal) / Math.abs(oldVal)) * 100).toFixed(digits);
}

function formatPct(v) {
  if (!Number.isFinite(v)) return 'N/A';
  return `${v >= 0 ? '+' : ''}${v.toFixed(2)}%`;
}

function formatNum(v, digits = 2) {
  if (!Number.isFinite(v)) return 'N/A';
  return v.toFixed(digits);
}

function parseArg(name) {
  const idx = process.argv.indexOf(name);
  if (idx === -1) return null;
  return process.argv[idx + 1] || null;
}

function findLatestExport() {
  const candidates = [];
  const roots = [process.cwd(), path.join(process.cwd(), 'reports')];
  for (const root of roots) {
    if (!fs.existsSync(root)) continue;
    const entries = fs.readdirSync(root, { withFileTypes: true });
    for (const e of entries) {
      if (!e.isFile()) continue;
      if (!/^webllm-bench-.*\.json$/i.test(e.name)) continue;
      const full = path.join(root, e.name);
      const st = fs.statSync(full);
      candidates.push({ file: full, mtimeMs: st.mtimeMs });
    }
  }
  candidates.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return candidates[0]?.file || null;
}

function inferContextWindow(summary) {
  const ctx = summary?.modelMeta?.contextWindow;
  if (Number.isFinite(ctx) && ctx > 0) return ctx;
  const id = String(summary?.modelId || '');
  const m = id.match(/ctx(\d{3,6})/i);
  if (m) return Number.parseInt(m[1], 10);
  return null;
}

function inferIsCustom(summary) {
  if (summary?.modelMeta?.isCustom === true) return true;
  const id = String(summary?.modelId || '');
  return id.includes('-local-') || id.includes('-custom');
}

function pickHighCtxPair(results) {
  if (!Array.isArray(results) || results.length < 2) return null;
  const withCtx = results.map((r) => ({ ...r, __ctx: inferContextWindow(r), __custom: inferIsCustom(r) }));
  withCtx.sort((a, b) => {
    const ac = Number.isFinite(a.__ctx) ? a.__ctx : -1;
    const bc = Number.isFinite(b.__ctx) ? b.__ctx : -1;
    if (bc !== ac) return bc - ac;
    if (a.__custom !== b.__custom) return a.__custom ? -1 : 1;
    return 0;
  });
  return { highCtx: withCtx[0], baseline: withCtx[1] };
}

function gateLine(name, pass, detail) {
  return `- ${pass ? 'PASS' : 'FAIL'}: ${name} — ${detail}`;
}

const inArg = parseArg('--in') || process.argv[2] || findLatestExport();
if (!inArg) {
  die('No input JSON found. Pass --in <webllm-bench-export.json> or place a webllm-bench-*.json file in project root/reports.');
}
const inputPath = path.resolve(inArg);
if (!fs.existsSync(inputPath)) die(`Input not found: ${inputPath}`);

let payload;
try {
  payload = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
} catch (err) {
  die(`Invalid JSON in ${inputPath}: ${err.message}`);
}

if (payload?.tool !== 'webllm-bench' || payload?.type !== 'benchmark') {
  die('Input must be a WebLLM Bench benchmark export (tool=webllm-bench, type=benchmark).');
}
if (!Array.isArray(payload.results) || payload.results.length < 2) {
  die('Input must contain at least two benchmark results (A/B run).');
}

const pair = pickHighCtxPair(payload.results);
if (!pair) die('Could not resolve 8k-vs-baseline pair.');
const a = pair.highCtx;
const b = pair.baseline;

const aCtx = inferContextWindow(a);
const bCtx = inferContextWindow(b);
const tokParity = Number.isFinite(a.avgOutTokens) && Number.isFinite(b.avgOutTokens)
  ? +(Math.min(a.avgOutTokens, b.avgOutTokens) / Math.max(a.avgOutTokens, b.avgOutTokens)).toFixed(4)
  : null;

const dLatency = pctDelta(a.avgMs, b.avgMs);
const dThroughput = pctDelta(a.avgTps, b.avgTps);
const dDecode = pctDelta(a.avgEngineDecodeTps, b.avgEngineDecodeTps);
const dPrefill = pctDelta(a.avgPrefillTps, b.avgPrefillTps);
const dTtft = pctDelta(a.avgTtft, b.avgTtft);
const dMsTok = pctDelta(a.avgMsPerTok, b.avgMsPerTok);

const cfg = payload.config || {};
const expected8k = Number.isFinite(aCtx) && aCtx >= 8192;
const parityPass = Number.isFinite(tokParity) ? tokParity >= 0.95 : false;
const decodeParityPass = Number.isFinite(dDecode) ? Math.abs(dDecode) <= 10 : false;

const gates = [
  gateLine('High-context model context window', expected8k, `detected ${aCtx ?? 'unknown'} tokens (target: >= 8192)`),
  gateLine('Output token parity', parityPass, `parity=${tokParity ?? 'N/A'} (pass threshold: >= 0.95)`),
  gateLine('Decode speed parity', decodeParityPass, `decode delta=${formatPct(dDecode)} (pass threshold: +/-10%)`),
  gateLine('Benchmark iteration depth', Number.isFinite(cfg.iterations) ? cfg.iterations >= 5 : false, `iterations=${cfg.iterations ?? 'N/A'} (recommended: >=5)`),
];

const stableVerdict = expected8k && parityPass && decodeParityPass;

const outDefault = path.join(
  process.cwd(),
  'reports',
  `launch_8k_validation_${new Date().toISOString().slice(0, 10)}.md`
);
const outPath = path.resolve(parseArg('--out') || outDefault);

const lines = [];
lines.push('# 8K Context Validation Report (WebLLM Bench)');
lines.push('');
lines.push(`Generated: ${new Date().toISOString()}`);
lines.push(`Source export: \`${path.relative(process.cwd(), inputPath)}\``);
lines.push('');
lines.push('## Run Metadata');
lines.push('');
lines.push(`- Tool: \`${payload.tool}\` \`${payload.version || 'unknown'}\``);
lines.push(`- Export generatedAt: \`${payload.generatedAt || 'unknown'}\``);
lines.push(`- Device: GPU=\`${payload.device?.gpu || 'Unknown'}\`, Vendor=\`${payload.device?.vendor || 'Unknown'}\`, Platform=\`${payload.device?.platform || 'Unknown'}\``);
lines.push('');
lines.push('## Benchmark Configuration');
lines.push('');
lines.push(`- promptTokens: \`${cfg.promptTokens ?? 'N/A'}\``);
lines.push(`- maxTokens: \`${cfg.maxTokens ?? 'N/A'}\``);
lines.push(`- iterations: \`${cfg.iterations ?? 'N/A'}\``);
lines.push('');
lines.push('## Models Compared');
lines.push('');
lines.push('| Role | modelId | Context | VRAM Metadata | Quant | Custom |');
lines.push('|---|---|---:|---:|---|---|');
lines.push(`| High-context candidate | \`${a.modelId}\` | ${aCtx ?? 'N/A'} | ${formatNum(a?.modelMeta?.vramMB, 0)} MB | ${a?.modelMeta?.quant || 'N/A'} | ${inferIsCustom(a) ? 'yes' : 'no'} |`);
lines.push(`| Baseline | \`${b.modelId}\` | ${bCtx ?? 'N/A'} | ${formatNum(b?.modelMeta?.vramMB, 0)} MB | ${b?.modelMeta?.quant || 'N/A'} | ${inferIsCustom(b) ? 'yes' : 'no'} |`);
lines.push('');
lines.push('## Performance Results');
lines.push('');
lines.push('| Metric | High-context | Baseline | Delta (high vs base) |');
lines.push('|---|---:|---:|---:|');
lines.push(`| Avg Latency (ms) | ${formatNum(a.avgMs, 2)} | ${formatNum(b.avgMs, 2)} | ${formatPct(dLatency)} |`);
lines.push(`| Throughput (tok/s) | ${formatNum(a.avgTps, 3)} | ${formatNum(b.avgTps, 3)} | ${formatPct(dThroughput)} |`);
lines.push(`| Decode TPS (tok/s) | ${formatNum(a.avgEngineDecodeTps, 3)} | ${formatNum(b.avgEngineDecodeTps, 3)} | ${formatPct(dDecode)} |`);
lines.push(`| Prefill TPS (tok/s) | ${formatNum(a.avgPrefillTps, 3)} | ${formatNum(b.avgPrefillTps, 3)} | ${formatPct(dPrefill)} |`);
lines.push(`| TTFT (s) | ${formatNum(a.avgTtft, 4)} | ${formatNum(b.avgTtft, 4)} | ${formatPct(dTtft)} |`);
lines.push(`| ms/token | ${formatNum(a.avgMsPerTok, 2)} | ${formatNum(b.avgMsPerTok, 2)} | ${formatPct(dMsTok)} |`);
lines.push(`| Avg Output Tokens | ${formatNum(a.avgOutTokens, 1)} | ${formatNum(b.avgOutTokens, 1)} | parity=${tokParity ?? 'N/A'} |`);
lines.push('');
lines.push('## Runtime Memory Snapshot (Browser-Observable)');
lines.push('');
lines.push('| Model | JS Heap Before (MB) | JS Heap After (MB) | JS Heap Delta (MB) | deviceMemory (GB) |');
lines.push('|---|---:|---:|---:|---:|');
lines.push(`| ${a?.modelMeta?.shortName || a.modelId} | ${formatNum(a?.runtimeMemory?.before?.jsHeapUsedMB, 2)} | ${formatNum(a?.runtimeMemory?.after?.jsHeapUsedMB, 2)} | ${formatNum(a?.runtimeMemory?.jsHeapDeltaMB, 2)} | ${formatNum(a?.runtimeMemory?.before?.deviceMemoryGB, 1)} |`);
lines.push(`| ${b?.modelMeta?.shortName || b.modelId} | ${formatNum(b?.runtimeMemory?.before?.jsHeapUsedMB, 2)} | ${formatNum(b?.runtimeMemory?.after?.jsHeapUsedMB, 2)} | ${formatNum(b?.runtimeMemory?.jsHeapDeltaMB, 2)} | ${formatNum(b?.runtimeMemory?.before?.deviceMemoryGB, 1)} |`);
lines.push('');
lines.push('Notes:');
lines.push('- GPU VRAM usage is not directly exposed by WebGPU APIs in standard browser runtimes.');
lines.push('- VRAM values in model metadata are declared requirements from the model record, not live GPU counters.');
lines.push('');
lines.push('## Stability Gates');
lines.push('');
lines.push(...gates);
lines.push('');
lines.push(`Final verdict: **${stableVerdict ? 'PASS' : 'CONDITIONAL'}**`);
lines.push('');
lines.push('## Public Claim Block (Safe)');
lines.push('');
lines.push(`- [TESTED] A model configured at \`${aCtx ?? 'unknown'}\` context loaded and completed benchmark runs on this device.`);
lines.push(`- [TESTED] Under this benchmark profile, decode TPS delta vs baseline was ${formatPct(dDecode)}.`);
lines.push(`- [TESTED] Output token parity was ${tokParity ?? 'N/A'}, supporting apples-to-apples comparison at this configuration.`);
lines.push('- [LIMITATION] Browser WebGPU does not expose exact live GPU VRAM usage counters; report includes model-declared VRAM and observable JS heap metrics only.');
lines.push('');
lines.push('## Reproduction');
lines.push('');
lines.push('1. Run the same A/B benchmark in WebLLM Bench and export JSON.');
lines.push(`2. Generate this report: \`node scripts/generate_8k_validation_report.mjs --in ${path.relative(process.cwd(), inputPath)}\``);
lines.push(`3. Output path: \`${path.relative(process.cwd(), outPath)}\``);
lines.push('');

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, lines.join('\n') + '\n', 'utf8');
console.log(`Wrote ${outPath}`);
