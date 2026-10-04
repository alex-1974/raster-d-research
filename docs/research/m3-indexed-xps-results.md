# M3 counted scalar loop: qualified negative XPS result

The explicit indexed row loop fails the placement-stability goal. Native
placement loses all twenty small approved expanded-case medians in both block
lengths; even the favorable offsets 0/8 lose twelve of twenty. Keep this
candidate as a negative Research result. No Production promotion is selected.

## Evidence qualification

Raw archive `raster-indexed-xps-run-I83RE1.tar.gz`, 31,770,547 bytes, SHA256
`3450ab11607403b93f564a3eac8fb8ddd7649349abcf52888b20dce4bcc1a89a`.
Measured Research source `4f93ec4814e1d346551de1c0be245dc4694d7967`;
Production `7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`.
DMD2.111.0, LDC1.41.0/frontend2.111.0, DUB1.40.0; same XPS qualification
method as PR34, CPU0 affinity, unmonitored frequency and thermal conditions.

Both root manifests pass: 1,664 extended launcher entries and 1,658 original
collector entries. Exact full replay reproduces 4,104 summary rows. All
144 process files are present: 221,616 timed blocks and 382,701,672 calls.
Six processes run per compiler/position/consumer/block combination.

Own, selection-parent and boundary-harness hashes match the qualified source.
Full replay confirms identical generated inputs, 72 cross-cohort backing
fingerprints, actual scalar calls at both selected dispatchers, exact entry
offsets, fixed other executable function entries across the four controlled
placements, and identical new scalar bytes through first return in all twenty
DMD mode/position cases. The new scalar SHA256 is
`1e12d663df492a5320df276f34039af51cd4c52b8cc9a5c63e9a23712473ec4d`.
The code gate correctly distinguishes it from PR34's body.

Inherited actual-source gates pass: 40 unittest modules, 72 full-public
conversion cases, 96 unchanged Copy controls, 54 public selection-boundary
cases, 18 shared-backing cases, guard pages, bitwise/four-rounding-mode
oracles and positive/negative trust and attribute probes. Safety correctness
does not establish performance acceptance.

## Contiguous 31x17 anchor

Median paired **Original / candidate** timing ratios across six processes;
greater than 1 favors the candidate. `selected64` denotes this indexed-loop
variant. Each ratio compares forms within the same binary/process.

| Scalar entry mod32 | Prior short | Prior long | Expanded short | Expanded long |
|---|---:|---:|---:|---:|
| Native (20) | 0.826869 | 0.833498 | 0.833023 | 0.834518 |
| 0 | 1.240538 | 1.227711 | 1.227485 | 1.224444 |
| 8 | 1.232812 | 1.231589 | 1.229907 | 1.208617 |
| 16 | 0.830625 | 0.830607 | 0.835503 | 0.838873 |
| 24 | 0.824831 | 0.832494 | 0.832462 | 0.837239 |

The candidate takes about 19–21% more time at native/16/24, and about
17–19% less time at 0/8. Every process loses at native for this anchor in
all four modes. This remains a large placement effect despite changed code.

Expanded-long call medians across controlled offsets are 528.247–794.739 ns
for the candidate, 629.395–666.577 ns for Original and 541.614–569.348 ns
for unconditional SIMD. Comparison forms vary between cohorts; the scalar
variation is substantially larger. Cohorts execute in sequence and are not
paired observations, so these ranges do not estimate a precise causal
cross-binary speedup.

## Small layouts and large anchor

Small approved expanded cases are widths below 64 with the five non-universal
layouts, twenty cases per mode. Universal fallback is separately present in
the full summary.

| DMD placement | Losing medians, expanded short | Losing medians, expanded long |
|---|---:|---:|
| Native | 20/20 | 20/20 |
| 0 | 12/20 | 12/20 |
| 8 | 12/20 | 12/20 |
| 16 | 20/20 | 20/20 |
| 24 | 20/20 | 20/20 |

In native expanded-long, all twenty cases lose in every process. The losing
cases at 0/8 occur in padded, repeated-source and negative-stride layouts;
many also lose in every process. A win for the contiguous anchor cannot
qualify the overall policy.

PR34's previous value-foreach study had zero losing small approved medians
at 0/8, while native lost 19/20 short and 18/20 long. This indexed study
therefore fails to improve the acceptance picture. Those studies have
different collection times and binaries: do not treat their ratio difference
as a paired measurement of the isolated source edit.

DMD 2048x512 contiguous Original/candidate ratios span 2.74–3.15 across
all modes/positions. The vector path is unchanged; its gains do not rescue
the scalar regressions or establish that the indexed source improved SIMD.
In expanded modes the complete D candidate remains about 2.26–2.48x the
separately compiled C++ approved-execution diagnostic. That diagnostic
excludes the D public validation boundary and is not the same API scope.
LDC uses the unchanged inactive declaration; its small contiguous ratios
span 0.939393–0.965969. No DMD-only source effect is attributed to LDC.

Expanded modes remain the focused 72-workload matrices, not the full
438-workload qualification or a universal threshold study.

## Code shape and interpretation

DMD now emits two adjacent bounds compare/jae pairs inside the scalar sample
loop, followed by its loop compare/jb. The previous value-foreach body had
one such bounds branch. The source edit produces different code while
retaining safe checks; it does not eliminate the bounds work.

| Entry mod32 | First bounds pair | Second bounds pair | Sample-loop pair | Row-loop pair |
|---|---|---|---|---|
| Native 20 | Inside | Inside | Crosses | Inside |
| 0 | Inside | Inside | Inside | Inside |
| 8 | Inside | Inside | Inside | Inside |
| 16 | Inside | Crosses | Inside | Inside |
| 24 | Crosses | Inside | Inside | Inside |

These placements remain consistent with the JCC/cache hypothesis discussed
in PR34, without proving its mechanism. No counters or instruction trace
were collected. Entry movement changes call displacement and cache placement;
the gate fixes other function addresses, not all code bytes or cache state.
The candidate is rejected on measured regressions, independently of whether
that hypothesis explains them.

## Retained results and replay

The uploaded archive identified above contains the raw timing, gate and linked
assembly evidence. The repository retains a derived
[qualification record](../../experiments/m3_conversion_indexed/evidence/xps-2026-10-04.json)
and losslessly compressed
[complete summary](../../experiments/m3_conversion_indexed/evidence/xps-2026-10-04-summary.csv.gz).
These do not replace the complete raw archive.

```bash
python3 tools/research/qualify_m3_indexed_xps.py /path/to/evidence /path/to/raster-indexed-xps-run-I83RE1.tar.gz > /tmp/indexed-qualified.json
cmp /tmp/indexed-qualified.json experiments/m3_conversion_indexed/evidence/xps-2026-10-04.json
```

Next research should target a safe scalar iteration that avoids the added
independent index checks, then qualify its ordinary-build behavior and all
controlled placements. No bounds-check disabling, new trust or Production
promotion follows from this result.
