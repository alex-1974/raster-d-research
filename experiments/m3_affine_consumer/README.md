# Checked affine bounds: production-shaped consumer gate

Production source baseline: `252bc9ab0c868820a9dc5b2432119d8ac0f15903`.
Research continuation of Issue #15; no production edits or public API changes.

`generate.py` verifies SHA-256 of the two production operation modules before
generating research-only variants. Its edits change module/operation identity,
reuse the production error enum and redirect the relation import. All validation,
error ordering, arithmetic-failure enumeration fallbacks and execution code stay
identical to the pinned production source. Generated files are disposable and
ignored. No Canonical point-transform executor is added.

The relation wrapper calls the **same checked implementation** qualified by
Gates 1–3. Only proven disjointness skips exact classification; overlapping or
unrepresentable bounds call the existing exact classifier. Package access to
three research symbols was widened to `package(raster)`; their bodies are unchanged.

## Correctness

- inherited operation unit tests include invalid planes, error precedence,
  shape/halo failure, empty success without callback invocation, noninjective
  destination, real overlap/no writes, signed strides, POD samples and direct
  defensive enumeration-fallback checks;
- four differential shared-backing probes: point transform/neighbourhood,
  even/odd sparse-disjoint samples and genuine overlap;
- relation-only fixtures prove overlapping-envelope sparse fallback,
  genuine overlap, unrepresentable bounds preserving exact classification, and
  invalid sample size preserving `arithmeticFailure`;
- large differently shaped neighbourhood consumer: 2050×514 required source,
  2048×512 destination;
- full expected output **and padding** fingerprint checked after every operation,
  outside the timer, with explicit failure rather than release-disabled assert;
- positive/negative source and destination rows, padded Canonical and Universal
  sample stride +2/-2.

Arithmetic-failure input is not fabricated into a dereferenced raster view.
The operation-local defensive fallback remains source-identical and its
inherited direct tests run under both compilers.

## Reproduce

Keep this repository and pinned `raster-d` as sibling directories:

```sh
python3 experiments/m3_affine_consumer/generate.py
dub test --root=experiments/m3_affine_consumer --compiler=dmd
dub test --root=experiments/m3_affine_consumer --compiler=ldc2
dub run --root=experiments/m3_affine_consumer --compiler=dmd --build=release --force
dub run --root=experiments/m3_affine_consumer --compiler=ldc2 --build=release --force
```

The timer includes operation invocation/dispatch. It excludes allocation,
initialization, backing construction and fingerprinting. Both operands and
destination allocations are created before timing. Two warmups and nine raw
samples per variant are retained; variant order alternates. Reported bytes cover
allocated source, two outputs and expected-output fixture. Timing thresholds
are informational, never correctness gates.

## Current evidence and remaining gates

Container diagnostics are retained under `evidence/2026-09-30-container/`:
DMD 2.111.0 and LDC 1.41.0 / LLVM 20.1.5, x86-64. Both inherited unittest
suites and both complete release consumer matrices passed. Existing Gates 1–3
were also rerun successfully with the unchanged arithmetic bodies.

These timings are not a stable local reference baseline. Concurrent workload,
virtualization and timer/closure overhead can affect absolute times and ratios.
Do not substitute them for three independent runs on the XPS, particularly its
LDC 1.41 / LLVM 19.1.7 build.

CI pins production by commit and reruns existing affine gates plus the generated
consumer unittest/release gates. CI status must be checked for the pushed head.

KEEP for continued qualification of the shared checked prefilter. Production
promotion, exact integration point and stable XPS measurement remain pending.
Point-transform Issue #14 stays deferred until the relation handoff. Cross-type
reuse stays deferred.

## XPS reference result

Three independent process executions per compiler are now qualified on the
Intel Core i7-9750H with DMD 2.111.0 and LDC 1.41.0 / LLVM 19.1.7.
Both semantic suites and all complete consumer matrices passed. Hosted CI for
the harness head also passed in run `36774234927`.

Raw logs, provenance and detailed results are in
`evidence/2026-09-30-xps/SUMMARY.md`. Recompute and verify their summary:

```sh
python3 experiments/m3_affine_consumer/summarize.py \
  experiments/m3_affine_consumer/evidence/2026-09-30-xps
```

Across all four large row-direction combinations and three executions,
transform speedup is 9.765–10.141× on DMD and 11.350–11.796× on LDC;
neighbourhood speedup is 1.322–1.391× and 1.955–2.027× respectively.
The local consumer gate is satisfied; production integration and its independent
contract/visibility tests are the next step.
