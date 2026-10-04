# M3.11 scalar boundary and controlled linked placement

Refs #32 and #22; follows the static linked-code finding in PR33. This is an
experimental qualification harness, not a selected Production optimization.
Production remains pinned to PR61 at
`7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`. Parent selection sources are checked
against the twelve hashes recorded by its qualified VM cohort. No parent
experiment or Production file is modified.

## Candidate and comparison

Reuse the full selected width-64 operation, preserving its validation, overlap
fallback, exact SIMD primitive and approved row borrows. Only the selected
scalar template declaration is adapted: where `vectorEnabled` is true (DMD
x86-64, portable override off), `pragma(inline, false)` preserves the scalar
row executor as a function. The inactive alternative is the original template
declaration. LDC, forced portable and other targets retain that declaration.
No new pointer operations, instructions, public exports or `@trusted` code are
introduced. Compiler safety/attribute gates still apply to the actual source.

Each binary compares complete public Original, selected-with-boundary and
unconditional SIMD calls. Expanded consumers also retain the separately
compiled C++ approved-execution reference, with its original narrower scope.
The selected column is still named `selected64` by the inherited parser;
`collection.json` explicitly identifies this study as the boundary variant.

Five DMD cohorts are separate builds: normal linker placement (`native`) and
scalar function entry positions 0/8/16/24 modulo 32. A GNU linker fragment
extracts just the ubyte/float selected scalar function into an executable
section occupying one fixed-size page. All four offsets reserve the same
page size. The collector verifies the exact entry offset and **a real call to
the selected scalar function in each flat and affine dispatcher**. Replay
compares every other retained executable function entry across all four
controlled replicas of the same consumer. It fails if another entry moves.
This checks addresses, not identical cache state or an instruction trace.

The original scalar code and SIMD core are not padded or rewritten. Linker
padding belongs to unreachable section space outside the function entry.
The GNU C smoke test independently checks the linker technique, all offsets,
executable behavior and fixed other function addresses. It does not establish
D compiler semantics or performance.

This tests placement sensitivity and an explicit compiler boundary together.
It cannot alone attribute all changes to JCC behavior or establish whether
microcode/cache effects caused an earlier run. Native versus controlled
cohorts also have different executable layout. Original and unconditional
paths are measured inside every binary to expose collateral variation. No
performance is inferred from source shape or instruction counts.

## Workloads and gates

Four modes: prior short/long with all eighteen PR29 anchors; expanded
short/long with the same **focused 72 workloads**, covering widths 63/64/65 at
heights 1/17/128 and the prior anchors, six layouts each. This step does not
re-run the full 438-workload short sweep and cannot qualify a universal policy.
Nine cyclic rounds, eight warmups/form and inherited iteration budgets
(262,144/8,388,608 samples per block, 8..4096 calls) remain unchanged.

All inherited actual-source semantic, unittest, attribute/trust, bitwise and
four-rounding-mode, guard-page, public boundary, Copy and shared-backing gates
run independently for each cohort/mode. Each timed block has complete backing
and immutable-source oracles outside timing. CPU affinity remains fixed;
frequency/thermal conditions are unmonitored. Separate binaries record actual
link commands/scripts, entry maps, full linked assembly and binary identity.
Full linked listings include consumer wrappers omitted by the earlier excerpt.

Default hardware collection: six processes for each of five DMD cohorts and
one LDC native control, four modes each (**144 processes**). CI repeats one
process per compiler/position/mode, without timing acceptance thresholds.
The summary enforces declared compiler/mode/process identities, every inherited
matrix/round/budget/order rule, 72 cross-cohort backing fingerprints and fixed
other-function addresses across the four controlled DMD replicas. Original,
candidate and unconditional paths within a process are paired; results from
different binaries/collection times are not inherently paired measurements.

## Run and independently replay

Requires Linux x86-64, DMD2.111.0, LDC1.41.0, DUB1.40.0, GNU ld/gcc/g++,
objdump and Python3, plus resolved pinned Production dependencies in a clean
sibling checkout. GNU section control is a Research-only Linux qualification
mechanism, not a consumer build requirement.

```bash
python3 experiments/m3_conversion_boundary/check_setup.py
python3 -u experiments/m3_conversion_boundary/collect.py /tmp/conversion-boundary
(cd /tmp/conversion-boundary && sha256sum -c SHA256SUMS)
python3 experiments/m3_conversion_boundary/collect.py /tmp/conversion-boundary --replay > /tmp/boundary-replayed.csv
cmp /tmp/boundary-replayed.csv /tmp/conversion-boundary/summary.csv
```

`--compiler dmd|ldc2|both`, `--positions native,0,8,16,24`, `--processes 1..6`.
Output must be new; Python assertions must be enabled. LDC runs only its native
control. A restricted single-position run cannot check invariance across all
four placements; the full collector is required for that gate.

## Current status

Local source adaptation, parent/Production hashes, Python syntax and four GNU
linker smoke replicas pass. The local execution environment has no D compiler;
D compilation, preserved actual call sites and inherited gates are qualified
through the new independent compiler CI. No six-process hardware timings or
candidate speedup are claimed before actual collection. Promotion remains
blocked pending the corrected candidate's semantic and performance evidence.
