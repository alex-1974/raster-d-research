# M3.7 full public bounded pointer-row conversion study

Research Issue #26 follows the codegen-only PR #25 and parent #22.
Production PR #61 is pinned at `7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`.
Nothing is assumed merged. Container collection date: 2026-10-03.

## Question and scope

Can replacing the approved ubyte-to-float safe row loop with count-bounded
pointer iteration materially improve the complete public call? Compare direct
float conversion and conversion through int. The latter remains exact across
all 256 input byte values. Candidate generation retains the full public and
internal conversion modules and all original validation, exact fallback and
Universal traversal. A small new trusted helper is explicitly proved and
challenged. It receives bounded slices rather than unbounded public pointers.
No manual SIMD or compiler/version specialization is selected here.

## Qualification

DMD 2.111.0 / LDC 1.41.0 (frontend 2.111.0, LLVM 20.1.5), DUB 1.40.0,
release optimization/inlining and DIP1000. Host: AMD EPYC 9V74 container,
affinity CPU 0; original mask and CPU information are retained. Frequency and
thermal state are unchanged and unmonitored. Imported-unit `-i` packaging is
shared across forms; it differs from a separately built DUB library consumer.

Both compiler families pass 40 imported unittest modules, including the
inherited public/internal tests. Separate release fixtures pass 72 conversion
backing cases and 96 unchanged Copy controls, including failure/error order,
no-write/empty and shared sparse/Canonical backing. Five row attribute
instantiations compile and the trust-removal challenges fail as intended.
Both new helpers also pass their isolated positive attribute/9-width executable
checks and fail isolated trust removal. Empty and 1/15/16/17/31/255/256/257 widths,
all byte values and complete guards are covered. See the experiment README for
the additional trust proof; Production trust remains unchanged.

Six processes per compiler, nine balanced cyclic rounds, three paths and 18
workloads yield 5,832 timed blocks and 8,475,840 full public calls. Every block
checks complete source/destination backing outside timing. All workload
fingerprints match across forms, processes and compilers. Eight warmup calls per
path/workload and all setup/oracles are outside timing. Binary hashes identify
one fixed binary per compiler. All 76 evidence checksums verify and summary
regeneration is byte-exact. The retained manifest does not include itself.
The standalone collector and source pins reproduce the experiment; full-object
identity hashes can vary with temporary paths.

## Observations

Ratios below are original/form, median of paired process medians, with minimum
and maximum paired process ratios. Larger than one favors the candidate.
Workload: 2048x512. These are within this container run, not confidence intervals
or XPS predictions.

| Compiler | Layout | pointer | pointer32 |
| --- | --- | --- | --- |
| dmd | contiguous | 1.013 (0.978–1.040) | 1.010 (0.968–1.042) |
| dmd | padded | 0.987 (0.964–1.058) | 1.001 (0.951–1.021) |
| dmd | negative-source | 0.996 (0.933–1.020) | 1.002 (0.972–1.015) |
| dmd | negative-both | 0.993 (0.924–1.008) | 1.008 (0.911–1.037) |
| dmd | repeated-source | 0.972 (0.966–1.020) | 0.991 (0.949–1.004) |
| dmd | universal | 1.002 (0.999–1.015) | 1.003 (1.000–1.020) |
| ldc2 | contiguous | 1.008 (1.003–1.011) | 1.005 (0.990–1.014) |
| ldc2 | padded | 1.012 (1.006–1.020) | 1.011 (1.003–1.020) |
| ldc2 | negative-source | 0.994 (0.983–1.002) | 1.003 (0.999–1.011) |
| ldc2 | negative-both | 0.996 (0.989–1.000) | 0.999 (0.992–1.002) |
| ldc2 | repeated-source | 1.000 (0.987–1.014) | 1.009 (0.993–1.015) |
| ldc2 | universal | 0.998 (0.996–1.000) | 0.998 (0.992–1.004) |

No large material improvement appears in these workloads. DMD large-case
ratios range on either side of one. LDC large positive-row paths show small
ratios around 1.01; negative-row paths remain around one. These small effects
are not qualified for a broader-trust Production implementation. Process
spread reaches 31.513% for DMD small padded original and 63.615% for LDC medium
contiguous original. Even large DMD pointer32 padded spread is 20.946%.
Results do not prove that every small gain/regression is absent.

Selected full-public and linked assembly retain scalar DMD row conversion;
pointer32 emits 32-bit scalar conversion instructions where the prior safe
intermediate-int form did not. LDC retains packed conversion instructions.
The alternative DMD instruction form did not establish the hoped-for runtime
gain. This does not identify the remaining bottleneck, and static sites cannot
be read as dynamic iteration costs. No C++ reference is timed here, so no ratio
against the historical scoped C++ executor or closure of its gap is claimed.

## Decision and next gate

Retain the original Production PR61 row source. Neither pointer form has shown
a material benefit sufficient to justify its additional trust. Preserve both
as measured Research alternatives; no Production promotion follows. Parent
Issue #22 stays open. An XPS collector is available if hardware qualification
is needed, but no upload is assumed and the local result is not promoted.

The next concrete question is whether an exact vector conversion primitive
can address the DMD scalar path while retaining the existing LDC/portable path.
That is a separate study requiring its own safety/ISA/tail proof, actual-source
negative controls, full public semantic tests and controlled container/XPS
measurements. The negative-row LDC gap also needs distinct investigation.
No claim that pointer arithmetic or an int cast alone solves either gap remains.

`.workspace/` was unavailable. Tracked AGENTS and the supplied canonical D
safety/benchmark, quality and Research/Git policy documents were consulted.
The existing `research/m3-point-transform` integration branch is retained;
this experiment does not migrate branches or merge previous PRs.

[Executable experiment and method](../../experiments/m3_conversion_pointer/README.md)
