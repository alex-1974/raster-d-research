# M3 same-binary Hybrid versus pointer diagnostic

Refs #39/#22. This follows PR #38 and the retained XPS pointer-vs-Hybrid
comparison. That comparison showed only a small DMD pointer advantage at width
64 and above, while the magnitude moved with binary placement and repeat pair.
The next question is therefore deliberately narrower: does the loop-form
difference survive when both forms live in the same executable and are measured
in the same process?

## Diagnostic

One executable contains four replicated Hybrid/Pointer pairs:

- pair 0 declares Hybrid then Pointer;
- pair 1 declares Pointer then Hybrid;
- pair 2 declares Hybrid then Pointer;
- pair 3 declares Pointer then Hybrid.

Every function is explicitly non-inlined. The build records the actual linked
symbol addresses, so declaration order is not assumed to equal final placement.
Widths 31 and 63 execute the identical original scalar foreach path in both
forms and therefore act as placement/noise controls. Widths 64 and above differ
only in the row execution body:

- Hybrid: paired remaining safe slices;
- Pointer: bounded local pointer/count traversal.

Both operate on the same validated equal-length slices. The pointer body remains
Research-only and is @trusted for local pointer indexing; no Production API or
implementation is changed.

Each pair alternates measurement order by repetition and reports medians from
17 samples after four warmups. Four independent same-binary pairs make it
possible to distinguish a stable loop-form effect from one favorable code
location. LDC is retained as a compiler/layout control, not as a proposed
Production specialization.

## Qualification rule

Do not promote the pointer form from this diagnostic alone. It is worth a
full-public follow-up only if:

1. width >= 64 favors Pointer repeatably across the replicated pairs rather
   than only one linked location;
2. widths 31/63, where both forms execute identical source, do not show
   differences of the same order as the claimed wide-loop gain;
3. repeated processes preserve the direction under ordinary native layout; and
4. the result is not contradicted by the LDC/noise control.

If these conditions fail, close the pointer source form as non-actionable
placement-sensitive evidence and continue with another explanation for the
remaining DMD conversion gap.

## Run

```bash
dub run \
  --root=experiments/m3_conversion_same_binary \
  --compiler=dmd \
  --build=release \
  --force
```

For hardware qualification, build once and run the same binary at least six
times. Preserve the executable hash and `nm -n` output with every cohort.
