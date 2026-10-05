# M3 LDC signed-row conversion boundary

Refs #44 and #22.

This experiment tests one narrow hypothesis left after the DMD conversion
promotions: LDC's full-public exact ubyte-to-float conversion remains slower on
layouts whose **source row stride is negative** because the signed outer-row
traversal inhibits optimization of the otherwise simple unit-stride row loop.

The candidate changes only the optimizer boundary. Under LDC, selector form 1
calls a `pragma(inline, false)` safe row helper when the approved source row
stride is negative. No pointer trust, SIMD, reassociation, API or semantic
change is introduced. DMD ignores the selector and remains current Production.

Controls deliberately include:

- contiguous and padded positive-source rows;
- negative-target-only rows;
- repeated-source rows;
- Universal sample-stride-two traversal;
- small and large shapes.

A useful result must therefore distinguish **negative source direction** from
negative destination direction or generic non-contiguous layout.

Production baseline:

```text
dd5b753b3e6e062aa679a31bfdaa45a16adf533c
```

Promotion is not implied by container timing. First require DMD/LDC semantic
and public-contract gates, then inspect LDC codegen, then run the same fixed
binary on the reference XPS.
