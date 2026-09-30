# XPS reference qualification — 2026-09-30

Production baseline: `252bc9ab0c868820a9dc5b2432119d8ac0f15903`.
Research consumer harness: `3f8733a0b8019ee1f078d5c216300a1ed6a6ce24`.
User ran the supplied pinned-checkout instructions with three separate process
executions per compiler. Raw logs are preserved without edits.
Uploaded `logs.tar.gz` SHA-256:
`4a992d93dd1c33516a0cc57d72927abf1b11337fad292b6d4464357ef7147e08`.

Environment: Intel Core i7-9750H, x86-64, 6 cores / 12 threads,
Linux 6.17.0-22-generic; DMD 2.111.0; LDC 1.41.0 / frontend 2.111.0 /
LLVM 19.1.7; DUB 1.40.0. Dependency build logs identify mir-algorithm 3.22.4
and mir-core 1.7.4. Source hashes were checked by the generator.

Both unittest suites passed (three modules: inherited transform,
neighbourhood and explicit relation fallback fixtures). All six process
executions completed successfully, including four shared-backing probes each.
Full output/padding fingerprints agree across all three runs and both compilers
for each layout. All reported medians and rounded speedups were independently
recomputed from the raw nine-sample arrays.

Reproduce this summary from repository root:

```sh
python3 experiments/m3_affine_consumer/summarize.py \
  experiments/m3_affine_consumer/evidence/2026-09-30-xps
```

| Compiler | Consumer | Source → output | Rows S/D | Sample stride | Public ms | Bounds ms | Median speedup | Speedup min–max | Bounds spread |
|---|---|---|---|---:|---:|---:|---:|---:|---:|
| dmd | transform | 2048x512 → 2048x512 | +/+ | 1 | 118.5762 | 11.9097 | 9.821 | 9.777–9.956 | 4.30% |
| dmd | transform | 2048x512 → 2048x512 | +/− | 1 | 121.6337 | 12.1586 | 9.954 | 9.845–10.004 | 3.15% |
| dmd | transform | 2048x512 → 2048x512 | −/+ | 1 | 123.4365 | 12.4308 | 9.955 | 9.765–10.141 | 4.76% |
| dmd | transform | 2048x512 → 2048x512 | −/− | 1 | 123.7053 | 12.3685 | 10.029 | 9.975–10.066 | 4.42% |
| dmd | transform | 31x17 → 31x17 | +/− | 2 | 0.1297 | 0.0065 | 19.984 | 19.954–21.957 | 47.69% |
| dmd | transform | 31x17 → 31x17 | −/+ | -2 | 0.1215 | 0.0062 | 19.597 | 19.597–21.400 | 4.84% |
| dmd | neighbourhood | 2050x514 → 2048x512 | +/+ | 1 | 98.4489 | 74.4694 | 1.328 | 1.322–1.342 | 2.28% |
| dmd | neighbourhood | 2050x514 → 2048x512 | +/− | 1 | 99.6926 | 74.2680 | 1.342 | 1.332–1.346 | 0.22% |
| dmd | neighbourhood | 2050x514 → 2048x512 | −/+ | 1 | 103.6733 | 75.1414 | 1.380 | 1.377–1.391 | 0.79% |
| dmd | neighbourhood | 2050x514 → 2048x512 | −/− | 1 | 100.1759 | 74.6603 | 1.340 | 1.327–1.374 | 1.49% |
| dmd | neighbourhood | 33x19 → 31x17 | +/− | 2 | 0.0664 | 0.0378 | 1.757 | 1.757–1.758 | 4.76% |
| dmd | neighbourhood | 33x19 → 31x17 | −/+ | -2 | 0.0682 | 0.0378 | 1.806 | 1.804–1.808 | 4.76% |
| ldc2 | transform | 2048x512 → 2048x512 | +/+ | 1 | 39.2533 | 3.4170 | 11.524 | 11.488–11.583 | 1.92% |
| ldc2 | transform | 2048x512 → 2048x512 | +/− | 1 | 39.3493 | 3.4487 | 11.391 | 11.350–11.509 | 2.58% |
| ldc2 | transform | 2048x512 → 2048x512 | −/+ | 1 | 40.8594 | 3.4700 | 11.775 | 11.559–11.796 | 3.86% |
| ldc2 | transform | 2048x512 → 2048x512 | −/− | 1 | 39.9972 | 3.4691 | 11.530 | 11.473–11.552 | 6.76% |
| ldc2 | transform | 31x17 → 31x17 | +/− | 2 | 0.0428 | 0.0017 | 24.471 | 24.167–25.176 | 5.88% |
| ldc2 | transform | 31x17 → 31x17 | −/+ | -2 | 0.0419 | 0.0018 | 23.667 | 22.611–24.647 | 5.56% |
| ldc2 | neighbourhood | 2050x514 → 2048x512 | +/+ | 1 | 16.7531 | 8.5675 | 1.983 | 1.955–2.011 | 6.18% |
| ldc2 | neighbourhood | 2050x514 → 2048x512 | +/− | 1 | 17.0250 | 8.5578 | 1.985 | 1.971–2.027 | 7.06% |
| ldc2 | neighbourhood | 2050x514 → 2048x512 | −/+ | 1 | 16.9491 | 8.5699 | 1.978 | 1.966–1.984 | 5.84% |
| ldc2 | neighbourhood | 2050x514 → 2048x512 | −/− | 1 | 16.8108 | 8.5524 | 1.993 | 1.966–1.995 | 4.32% |
| ldc2 | neighbourhood | 33x19 → 31x17 | +/− | 2 | 0.0141 | 0.0042 | 3.357 | 3.349–3.366 | 4.76% |
| ldc2 | neighbourhood | 33x19 → 31x17 | −/+ | -2 | 0.0144 | 0.0042 | 3.439 | 3.429–3.442 | 4.76% |

Verified: 72 cases, 1296 timed operations, six completed process executions.

Times are medians of three per-process medians (nine samples each).
Speedup is the median of three paired median ratios; its range spans those three ratios.
Bounds spread = (maximum − minimum) / median of the three process medians.

## Interpretation

For the 2048×512 output matrix across all four row-direction combinations,
all three process executions produced gains:

- transform / DMD: paired median speedups 9.765–10.141;
- transform / LDC: 11.350–11.796;
- neighbourhood / DMD: 1.322–1.391;
- neighbourhood / LDC: 1.955–2.027.

This isolates the relation optimization: execution is identical between A and
B. The transform still retains its existing per-sample view traversal. The
neighbourhood still retains its existing M3.1 dispatch. No SIMD, new Canonical
executor, threading or compiler specialization was introduced.

Large-case candidate median spread across the three process executions is
0.22–7.06%. One microsecond-scale DMD Universal-transform case has a 47.69%
candidate spread; its absolute timing is unsuitable as a tight regression
threshold. Small-layout correctness remains supported. CPU affinity, power mode,
background load and temperature were not recorded, so these are a repeatable
reference-session comparison, not a universal timing guarantee.

KEEP for a production handoff of the shared checked same-type prefilter.
The local reference consumer gate is satisfied on both frontend-baseline
compilers, including the local LLVM 19.1.7 generation.

Recommended next integration shape: one package-internal validated-raster
relation wrapper adjacent to the exact relation, with a shared checked bounds
helper. Keep the exact algebraic classifier unchanged; overlapping or
unrepresentable bounds must route to it, and its arithmeticFailure must still
reach each operation's existing defensive enumeration. Do not put independent
bounds arithmetic into each operation. This is a handoff recommendation,
not yet a production ADR or source change.

Production integration requires its own contract/negative-import tests and
DMD/LDC gates. Same-type copy reuse should be checked against its contiguous
specialization before extending the handoff. Cross-type and AArch64 performance
remain unqualified. Point-transform Issue #14 remains deferred until the
relation handoff, followed by a new measurement of remaining execution costs.
