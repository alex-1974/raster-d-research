# Post-bounds point-transform executor qualification

Issue #14; production baseline `b263477bdbbe0dc3e8c469ac3867eda345ba364c`.
This experiment isolates execution after the merged bounds-prefilter change.
The historical `m3_point_transform` experiment remains unchanged.

`generate.py` checks the complete production transform source SHA-256 before
creating two ignored copies. It changes module/function identity, imports the
production error enum, and inserts one dispatch after all existing validation:
both sample strides equal one -> candidate executor -> success. The existing
Universal/sample-strided path and every error/fallback branch remain intact.
No relation implementation or transform expression is replaced. Each copy
retains all 11 production unittest blocks.

A is the current public production operation. B uses signed row pointers.
C constructs bounded row slices at two narrow trusted boundaries and runs the
inner loop in `@safe`. Both candidates preserve the arbitrary compile-time
`T -> T` transform and its attribute contract. Their safety argument relies on
validated reachable sample bytes, shape, destination injectivity and physical
disjointness established by the unchanged consumer. Trust challenges compile
the same helpers positively, then require pointer/slice diagnostics when their
`@trusted` markers are replaced with `@safe`.

The 41-case harness covers float and ubyte at 31x17, 256x128 and 2048x512:
contiguous rows and all four padded source/target row-sign combinations. Float,
ubyte and eight-byte POD also cover sample stride +2/-2 Universal fallback;
POD covers all four small padded row-sign combinations and contiguous rows.
Special floats include signed zero, infinities, NaN and normal minima, checked
bitwise against the public path for both affine and identity transforms. POD fingerprints enumerate every field (the
fixture has no padding).

Each timed call includes the full public validation/relation/dispatch work.
There are two warmups and nine samples per path. Cyclic order gives every path
three turns in each ordering position. Allocation/setup and the complete
source/output/padding checks are outside the timer. Every call's output is read;
release-mode checks throw on a mismatch and do not rely on disabled assertions.

With sibling `raster-d` at the pinned baseline and dmd/ldc2/dub on PATH:

```bash
experiments/m3_transform_executor/collect.sh /tmp/transform-xps 0
```

This generates candidates, runs inherited tests and trust challenges, records
verbose release compiler commands and binary hashes, pins measurements to the
requested CPU, runs three independent processes per compiler and validates the
raw medians and cross-process/compiler fingerprints. No frequency/thermal/VM
isolation is implied by CPU affinity. `summarize.py DIRECTORY` reproduces the
summary using only the Python standard library.

`codegen.sh` inspects exact isolated executor helpers for one question: whether
slice indexing prevents LDC vectorization or leaves DMD bounds-error edges.
Its entries are diagnostics, not the complete consumer benchmark; they do not
establish a whole-consumer explanation or authorize compiler specialization.

Decision and environment-specific findings are in
`docs/research/m3-transform-executor.md`. The archived container evidence is a
candidate-selection diagnostic; stable XPS qualification remains outstanding.
