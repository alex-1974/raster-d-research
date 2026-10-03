# M3.6 full public conversion codegen — 2026-10-03

## Problem and provenance

Reference XPS M3.5 evidence at research head
`9b3e709111364276d1f7383b6f14326327f6f21f` retains a DMD padded conversion
execution gap of 3.953–4.065x and signed negative-both LDC gap of
1.542–1.848x against the scoped C++ execution reference. Production PR #61
proposes the intermediate improvement; this audit pins its source at
`7dcdf01babf87e9a80af2864fbad75efe8e7d0ef` and does not assume it merged.

[Reproducer](../../experiments/m3_conversion_codegen/README.md) verifies
complete public/internal conversion, bounds and integration-fixture hashes.
Two safe forms preserve the complete operation and inherited tests: casting
through int, and a D float array expression adding positive zero. All values
in the ubyte domain remain exactly represented; no broader FP equivalence is
claimed. Original validated slices and their trust boundaries remain.

## Qualification

[Raw codegen and contract evidence](../../experiments/m3_conversion_codegen/evidence/2026-10-03-container/)
passes all 44 manifest entries. DMD 2.111.0 and LDC 1.41.0 (frontend 2.111.0,
LLVM 20.1.5) each pass forty imported unittest modules in a debug build and a
separate release fixture run: 72 full-public conversion backing cases plus 96
unchanged Copy controls. Every form passes actual-source positive attributes
and safe-negative row-formation probes. Selected assembly and commands are
retained verbatim; full scratch object/assembly hashes identify this run.

The compiler -i builds a relocatable object rooted at an actual public call.
Unlike an isolated helper, it includes the operation's validation, classification
and dispatch source. Its C ABI wrapper and imported-unit compilation differ
from final DUB linked consumers; downstream codegen is diagnostic. There is no
wall-clock measurement, causal percentage decomposition or performance win
claim. Imported source and temporary paths may change final artifact layout.

## Actual codegen findings

The following counts describe static instruction/relocation sites in the two
canonical sections convertApprovedUbyteToFloatAffine2D and executeApprovedRows.
They include the original Universal fallback present in the affine function;
they are not dynamic counts, iteration costs or speed ratios.

| Compiler | Form | Canonical sections | Scalar 64-bit cvtsi2ss sites | Packed cvtdq2ps sites | Bounds-handler relocations |
| --- | --- | --- | --- | --- | --- |
| dmd | original | 2 | 3 | 0 | 2 |
| dmd | signed | 2 | 3 | 0 | 2 |
| dmd | array | 2 | 3 | 0 | 3 |
| ldc2 | original | 2 | 0 | 4 | 0 |
| ldc2 | signed | 2 | 0 | 4 | 0 |
| ldc2 | array | 2 | 0 | 4 | 0 |

The original full-public DMD path has scalar cvtsi2ss using a 64-bit integer
operand. Casting through int does not select a 32-bit conversion in these
sections. The array expression also retains scalar 64-bit conversion and
adds one bounds-handler relocation site. Safe inner indexing retains a bounds
branch in the inspected DMD canonical loop. Handler references show codegen
shape, not observed failure or a runtime fraction attributable to checks.
LDC retains packed cvtdq2ps with scalar tails and no bounds-handler relocation
in these canonical sections across all three forms. This matches the broad
isolated-kernel finding with actual public source included, while preserving
the packaging limitation above.

## Decision and follow-up

- Keep the proposed Production row source. Neither safe alternative provides
  a demonstrated solution to the conversion gap; these codegen results alone
  cannot reject or establish small timing differences.
- Do not assume that an explicit int cast forces the desired DMD instruction
  or that a D array expression automatically vectorizes this operation.
- Research Issue #22 remains open. The next controlled complete-public study
  should compare pointer traversal and a separately justified exact vector
  primitive, retaining all validation/fallback and sample-byte contracts.
  Broader pointer-loop trust and any explicit SIMD need their own proof and
  attribute/safe-negative tests, full-public timings and XPS confirmation.
- Signed LDC rows still need controlled consumer measurements: existing packed
  codegen by itself does not explain the remaining signed-row timing gap.
- No Production change, compiler/version switch, bounds-check disabling,
  threading or AArch64 performance qualification follows from this audit.

The checkout has no .workspace hardlinks. Tracked AGENTS.md and supplied
relevant workspace policy govern this evidence-only study; the existing
research/m3-point-transform integration line is retained.
