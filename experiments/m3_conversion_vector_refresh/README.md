# M3 exact SSE2 conversion refresh

Refs #46, #32, #30, #28 and parent #22.

The old exact-vector work was qualified against an earlier scalar Production
proposal. Current Production has since gained:

- the DMD x86-64 bounded pointer row conversion for width >=64;
- the LDC x86-64 negative-source no-inline row boundary.

Historical SIMD/original ratios therefore cannot answer the remaining
Production question.

This refresh pins:

```text
raster-d/develop
24d948255df014c683d79c5508f13248806062dc
```

and generates one Research-only public operation with an out-of-band selector:

- form 0: exact current Production;
- form 1: on DMD x86-64 and width >=64, use the previously qualified exact
  sixteen-byte SSE2 ubyte-to-float row algorithm;
- width <64: exact current Production;
- LDC: exact current Production for both forms.

The selector is set outside the timed public call. All current validation,
error ordering, no-write, injectivity, exact overlap fallback, shared-backing,
empty and Universal semantics are retained.

## Why this is a refresh rather than new SIMD research

The vector algorithm is the same SSE2 unpack -> dword -> `CVTDQ2PS` sequence
used in the retained PR33 qualification, with the same bounded unaligned
16-byte load and four-float stores plus scalar tail. Only local Research helper
names differ.

The earlier work already retained bitwise, four-rounding-mode and guard-page
qualification. This refresh does not weaken those findings or claim they apply
to a different algorithm. Its new job is only to compare the already-qualified
algorithm against the **current DMD pointer Production path** through the full
public operation.

## Decision matrix

Timing covers widths 31, 63, 64, 65, 96, 256 and 2048 over:

- contiguous;
- padded;
- negative source;
- negative target only;
- negative both;
- repeated source;
- Universal sample-stride two.

Widths 31/63 and every LDC case are inactive controls. Universal is also an
inactive DMD control because the approved-row executor is not entered.

Promotion requires:

1. current Production and vector forms remain semantically identical;
2. inactive/control cases stay near parity;
3. DMD width >=64 shows a material repeatable full-public gain over the current
   pointer path on the reference XPS;
4. the improvement is broad enough to justify explicit SIMD complexity under
   the workspace measure-first rule.

No public API, fast-math, reassociation, threading or CPU-feature dispatch is
introduced by this experiment.
