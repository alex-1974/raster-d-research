# M3 same-binary Hybrid versus pointer — reference XPS qualification

## Provenance

Research head:

```text
103ecc64a1798e054ab3b11453221669c680ad26
```

Uploaded raw archive:

```text
raster-m3-same-binary-xps-20261005-092441.tar.gz
SHA256 c55f94b11319a8c4a49467afc183f4ed1b04e89ff21f19cca1ed130fd2158ee7
```

The archive contains 26 files. Its retained `SHA256SUMS` verifies every
payload file. The recorded host is an Intel Core i7-9750H on Linux x86-64,
DUB 1.40.0, with the experiment built separately under DMD 2.111.0 and
LDC 1.41.0. The collection did **not** pin one CPU: recorded process affinity
was CPUs 0-11. The recorded CPU0 governor was `powersave`; frequency and
thermal state were not continuously monitored. Those limitations prohibit
small timing claims but do not erase the very large DMD shared-entry signal.

One release binary per compiler was built, hashed and then executed six times.
Linked addresses for all eight separate-entry functions plus both shared-entry
functions were retained with `nm -n`.

## Why the shared-entry result is the decision evidence

The older separate-entry control remains strongly placement-sensitive even
inside one binary. On the XPS, identical-source widths 31 and 63 have DMD pooled
Hybrid/Pointer medians 1.248x and 1.282x, with very wide per-run ranges.
Separate-entry timings therefore remain diagnostic only.

The shared-entry functions remove that confound: both forms enter the same
function through the same call site. Widths below 64 return through the same
scalar body before the selector is inspected. Two shared functions reverse the
selector-to-body mapping to control branch/fallthrough layout.

### DMD 2.111.0

| Width | Hybrid / Pointer median | Min | Max |
| ---: | ---: | ---: | ---: |
| 31 | 1.000000 | 1.000000 | 1.000000 |
| 63 | 1.000000 | 1.000000 | 1.004785 |
| 64 | 4.384316 | 4.275000 | 4.478261 |
| 96 | 4.298891 | 4.020080 | 4.387435 |
| 128 | 4.259068 | 4.171053 | 4.506849 |
| 256 | 4.555634 | 4.363825 | 4.814815 |
| 512 | 4.683931 | 4.506401 | 4.839695 |
| 2048 | 4.843165 | 4.635896 | 5.061083 |

Across all width >=64 samples, the two reversed selector mappings have medians
4.606077x and 4.359332x. The identical-source narrow controls are therefore
orders of magnitude smaller than the wide body effect.

### LDC 1.41.0

| Width | Hybrid / Pointer median | Min | Max |
| ---: | ---: | ---: | ---: |
| 31 | 1.000000 | 1.000000 | 1.000000 |
| 63 | 1.000000 | 1.000000 | 1.026316 |
| 64 | 1.093841 | 1.058824 | 1.125000 |
| 96 | 1.066667 | 1.044444 | 1.085714 |
| 128 | 1.044218 | 0.824324 | 1.357143 |
| 256 | 1.000000 | 0.940476 | 1.153061 |
| 512 | 1.000000 | 0.968847 | 1.066667 |
| 2048 | 1.006117 | 1.003040 | 1.034783 |

The LDC wide pair medians are 1.034936x and 1.032313x. This supports a
compiler-specific DMD hypothesis rather than a family-wide source rule.

## Decision

The bounded pointer/count row body is now justified for a **full-public
DMD-only research candidate** at width >=64. LDC must preserve the current
qualified row path.

This result does not justify Production promotion by itself. The next candidate
must keep the complete public operation intact: validation, shape/error order,
destination injectivity, checked affine bounds, exact overlap fallback,
approved row borrowing, empty/no-write behavior and the public attributes/API.
Original/current and candidate execution must be selectable inside the same
full-public research binary so the XPS comparison does not return to a
separate-binary placement confound.

Promotion requires a fresh full-public XPS qualification against current
Production baseline `10549e045bfa5a99afe6552b0fb41b76fe203fa5`.
