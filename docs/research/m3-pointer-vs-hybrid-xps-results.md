# M3 bounded pointer/count versus paired-slice Hybrid: XPS result

The XPS comparison shows a small median DMD advantage for the bounded
pointer/count candidate at widths 64 and above, but the size changes across the
two ABBA pairs and DMD placements. The evidence does not establish a stable
enough improvement to promote the candidate.

## Qualification and provenance

Raw archive `raster-pointer-vs-hybrid-xps-8DP3OT.tar.gz`, 127,893,219 bytes,
SHA256 `f64b70b5a8c995950f092162c1269b87582022a980afeaa9fc9245feb6b5d36c`.
Production commit `7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`, Hybrid
`603e67b650a0287dadf77aabdb76da56eb41a390`, Pointer
`9ade083b49d5c2e4ac02e2d8270a17c4149fe176`. The ABBA order is
`hybrid-1`, `pointer-1`, `pointer-2`, `hybrid-2`; six processes were used for
each collection.

The XPS is an Intel Core i7-9750H running Linux x86-64, with DMD 2.111.0, LDC
1.41.0/frontend 2.111.0 and DUB 1.40.0. CPU affinity and the governor were
left unchanged. Frequency and thermal conditions were not controlled
continuously.

The root manifest verifies 6,673 files. Each of the four run directories
passes both its 1,658-entry extended and 1,658-entry original audit manifest.
All four runs contain 4,104 summary rows, and each supplied
`summary-replayed.csv` is byte-identical to its `summary.csv`.

This is an integrity and internal replay-file check. The exact collector
source versions identified by the run input hashes are not present in this
checkout, so I did not independently execute those collectors again. The
retained [qualification record](../../experiments/m3_conversion_pointer/evidence/xps-2026-10-04.json)
records the source hashes and checks. The complete 16,416-row summary is
[losslessly compressed](../../experiments/m3_conversion_pointer/evidence/xps-2026-10-04-summary.csv.gz),
and matched case calculations are in the
[comparison table](../../experiments/m3_conversion_pointer/evidence/xps-2026-10-04-comparison.csv).

## DMD, width 64 and above

Ratios below are **Hybrid time / Pointer time** over matched `selected64`
summary cases. Values above 1 favor Pointer. Each pair contains 600 matched
cases across DMD placements, widths, modes and layouts.

| ABBA pair | Median Hybrid / Pointer | Approximate Pointer time advantage |
|---|---:|---:|
| Hybrid 1 / Pointer 1 | 1.0143 | 1.4% |
| Hybrid 2 / Pointer 2 | 1.0440 | 4.2% |

The placement-level medians show why the pooled result is not yet a stable
qualification:

| DMD placement | Pair 1 | Pair 2 |
|---|---:|---:|
| Native | 1.0488 | 1.0498 |
| 0 | 1.0131 | 1.0034 |
| 8 | 1.0082 | 1.0326 |
| 16 | 0.9868 | 1.0709 |
| 24 | 1.0196 | 1.0519 |

At placement 16, the first pair slightly favors Hybrid while the second favors
Pointer by about 6.6% in time. Several other per-case distributions cross 1
even where their medians favor Pointer. The observed gain is therefore modest
relative to the variation across placements and repeats.

## Controls and placement sensitivity

The LDC path is intended to preserve its inactive declaration. Its median
Hybrid/Pointer ratio moves from `1.0007` in pair 1 to `0.9087` in pair 2; the
second pair makes Hybrid about 9% faster. This control shift warns that the
small DMD differences should not be read as a clean source-only effect.

The large DMD differences below width 64 are also informative. Both candidates
use the same `foreach` loop below 64, yet the medians are:

| Placement | Width 31, pair 1 / pair 2 | Width 63, pair 1 / pair 2 |
|---|---:|---:|
| Native | 1.381 / 1.399 | 1.452 / 1.468 |
| 24 | 1.762 / 1.914 | 1.988 / 2.032 |

These rows expose binary-layout and placement sensitivity outside the width
where the pointer helper is selected. They are not evidence that the helper
itself sped up those rows.

The ABBA sequence and six-process summaries improve on a single sequential
comparison, but cohorts remain separate binaries. The runs do not lock CPU
frequency or continuously monitor thermal state. The LDC movement and the
below-64 placement effects prevent attributing the modest DMD advantage to the
pointer loop alone.

## Decision

Keep the pointer/count implementation as a Research candidate. Do not promote
it to `raster-d` from this result. The next qualification would need to
separate code-layout effects from the loop change and show repeatable gains at
the ordinary native placement without regressions in the controlled positions.
The D-versus-C++ diagnostic remains a separate question: its C++ path does not
include the full D public validation boundary and is not an equivalent API
comparison.
