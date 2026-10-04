# M3 scalar boundary: XPS placement sensitivity

The preserved scalar executor is strongly placement-sensitive on this XPS.
Offsets 0 and 8 modulo 32 win in all measured small approved cases; native
placement still regresses in several layouts. Neither the no-inline boundary
alone nor a universal width-64 policy is qualified for Production.

## Qualification and provenance

Input archive: `raster-boundary-xps-run-WRfmq6.tar.gz`, 31,754,005 bytes,
SHA256 `6e66a3b43fe608e7b91f544338ef3a1d170d6ffc936e5ff3efae17eadd35fac2`.
Research source `cd293ff6443ebce0fdbeec1d2962eb85a4e13ec9`; Production
`7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`. DMD 2.111.0,
LDC 1.41.0/frontend 2.111.0, DUB 1.40.0, GNU ld 2.46.
Host: Intel i7-9750H, microcode 0xfa; affinity CPU 0. Frequency and thermal
conditions were not sampled. The collection runs separate binaries in cohort
order, so comparisons between cohorts are not paired observations.

Both root manifests pass: 1,664 launcher-extended entries and 1,658 original
collector entries. Own and parent source hashes match. Exact replay reproduces
all 4,104 summary rows. There are 144 process files, 221,616 timed blocks and
382,701,672 timed calls, six processes per cohort/mode.

All inherited actual-source gates passed: 40 unittest modules, 72 full-public
conversion cases, 96 Copy controls, 54 public boundary cases, 18 shared-backing
cases, guard pages, four rounding modes and positive/negative trust and
attribute probes. Full replay confirms 72 cross-cohort backing fingerprints,
identical generated inputs, actual calls from both selected dispatchers,
exact scalar entry offsets, and fixed other function entries across controlled
replicas in every consumer mode.

## Small contiguous anchor

Values are median paired **Original / candidate** timing ratios across six
processes; greater than 1 favors the candidate. The selected64 column here
means the preserved-boundary candidate. This is not a comparison against the
previous PR33 binary, whose layout differs.

| Scalar entry mod32 | Prior short | Prior long | Expanded short | Expanded long |
|---|---:|---:|---:|---:|
| Native (20) | 0.997904 | 0.996203 | 0.999206 | 1.000289 |
| 0 | 1.433242 | 1.431624 | 1.423705 | 1.438221 |
| 8 | 1.434219 | 1.443038 | 1.419368 | 1.426851 |
| 16 | 0.996859 | 0.998457 | 1.003107 | 1.011945 |
| 24 | 0.706967 | 0.709778 | 0.717626 | 0.718357 |

At 0/8 the candidate takes about 30% less time than Original; at 24 it takes
about 39–41% more time. In expanded-long the candidate call medians at 0/8
are 437.329/436.475 ns, versus 895.483 ns at 24. Original medians across the
four controlled cohorts are 620.276–646.936 ns and unconditional SIMD medians
are 531.580–551.611 ns. These controls vary, but by much less than the scalar
candidate. Short-block expanded Original varies more (612.978–681.288 ns),
so absolute cross-cohort differences should not be treated as precise paired
speedups.

## Layout and crossover scope

Each expanded mode has 20 small approved cases: widths 31 and 63, heights
covered by the focused matrix, and five non-universal layouts. At 0 and 8,
all 20 median ratios exceed 1 in both block lengths, and each of their six
process ratios also exceeds 1. The weakest process ratio is 1.033507 at 0
and 1.040338 at 8 across the two modes. The five prior small approved cases
also all win at both positions. At native placement, 19/20 expanded-short
and 18/20 expanded-long small approved medians lose. At 24 all 20 lose in
both modes. Universal fallback remains separately measured in the full
summary and is not counted as an approved scalar executor case.

The focused matrix contains 72 workloads per expanded mode, not the full
438-workload sweep. This result does not establish a universal threshold.
The LDC native control retains the original template declaration and shows
no systematic gain: its contiguous 31x17 Original/candidate ratios range
0.944678–0.964415. Small percentage differences there must not be attributed
to the inactive DMD no-inline adaptation.

For DMD 2048x512 contiguous, Original/candidate medians remain about
2.91–3.06 across all positions/modes. The vector path is unchanged by the
scalar-boundary adaptation; this is a within-binary result, not evidence
that no-inline improved SIMD. In expanded modes the complete D public
candidate still takes about 2.24–2.37 times the separately compiled C++
approved-execution diagnostic at this anchor. That C++ diagnostic excludes
the D public validation boundary and is not a like-for-like public API.

## Linked code and interpretation

All twenty DMD scalar bodies are byte-identical through the first return.
The three adjacent compare/branch pairs occur at the same relative offsets:

| Entry mod32 | Bounds compare/jae | Sample-loop compare/jb | Row-loop compare/jb |
|---|---|---|---|
| Native 20 | Crosses | Inside | Inside |
| 0 | Inside | Inside | Inside |
| 8 | Inside | Inside | Inside |
| 16 | Ends on boundary | Inside | Crosses |
| 24 | Inside | Crosses | Inside |

This is consistent with the previously documented JCC/cache hypothesis,
but it does not identify a causal CPU mechanism. No instruction trace or
performance-counter evidence was collected. Moving the scalar entry also
changes its call displacement and instruction-cache placement. The address
gate controls other function entries, not every executable byte or cache
state. Native is outside the four-position fixed-layout comparison.

The controlled experiment establishes a large repeatable placement effect
within this workload and host. It also rejects the assumption that preserving
the scalar function out of line alone makes the candidate robust.

## Retained results and replay

The complete uploaded archive is the raw evidence source identified above.
The repository retains the derived
[qualification record](../../experiments/m3_conversion_boundary/evidence/xps-2026-10-04.json)
and losslessly compressed
[complete summary](../../experiments/m3_conversion_boundary/evidence/xps-2026-10-04-summary.csv.gz).
These are not substitutes for the raw assembly, gates and process timings.

After extracting the archive, reproduce the record with:

```bash
python3 tools/research/qualify_m3_boundary_xps.py /path/to/evidence /path/to/raster-boundary-xps-run-WRfmq6.tar.gz > /tmp/boundary-qualified.json
cmp /tmp/boundary-qualified.json experiments/m3_conversion_boundary/evidence/xps-2026-10-04.json
```

Next research step: test a source-level scalar loop shape for stability across
all controlled positions while retaining actual-source safety and backing
gates. Keep linker padding as a diagnostic tool. Production promotion remains
blocked until the ordinary consumer build has stable measured behavior.
