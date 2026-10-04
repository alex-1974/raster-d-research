# M3 selection: linked small-path code placement

Refs #32/#22 and [PR33](https://github.com/alex-1974/raster-d-research/pull/33).
This is the next isolated **static inspection step**, using the XPS evidence
retained at `159ecfe3b39a7fa15a18f559037a337d16397388`. No new candidate,
compilation, hardware run or Production change is claimed. Repository AGENTS
and supplied canonical performance/toolchain rules apply; `.workspace/` is
unavailable. Existing Research branches retain their grandfathered destination.

## Question and result

Why does the below-width-64 route regress even though its original scalar
executor body is unchanged?

The retained linked DMD assembly contains the approved scalar loops **inlined
into both dispatchers**: `convertUbyteToFloatRasterPlane` for the flat path and
`convertApprovedUbyteToFloatAffine2D` for the affine path. Inspecting only the
separately emitted `executeApprovedRows` function would miss these loop sites.
The retained object excerpts have no relocation to its ubyte/float instantiation;
the complete consumer wrapper is not retained in the linked excerpt, so this
does not prove the helper is globally unreachable.

The ten scalar-loop instructions, including registers and operands, agree
across both forms, both routes and all four modes after normalizing branch
target addresses. This normalization does **not** claim byte-identical whole
functions, equal branch displacements, identical preceding validation or
identical dynamic execution. Source-level constancy therefore did preserve
this loop's instruction shape, but not its placement.

| Mode | Selected flat `jae` | Crosses 32 bytes | Selected affine tail `cmp`→`jb` span | Crosses 32 bytes | 31x17 contiguous original/selected |
| --- | --- | --- | --- | --- | ---: |
| prior-short | `0xc07fc..0xc0802` | yes | `0xbff7f..0xbff84` | yes | 0.693202 |
| prior-long | `0xc07fc..0xc0802` | yes | `0xbff7f..0xbff84` | yes | 0.693761 |
| sweep-short | `0xbfcac..0xbfcb2` | no | `0xbf42f..0xbf434` | no | 1.127215 |
| sweep-long | `0xc0d3c..0xc0d42` | yes | `0xc04bf..0xc04c4` | yes | 0.700025 |

Ranges use exclusive ends. Original flat bounds jumps and original affine
tail pairs stay within their 32-byte blocks in all four modes. Selected
non-contiguous unit-stride 31x17 medians also lose in prior/expanded-long modes.
The affine pair is a **candidate macro-fusion span**, not proof from hardware
counters that fusion occurred.

This positional correlation supports a focused hypothesis. It does not prove
that code placement explains all timings, Universal cases, LDC results or the
remaining C++ gap. Affinity was pinned but thermal/frequency conditions were
not sampled; no branch counters or instruction trace were captured.

## External mechanism: hypothesis only

[Intel's JCC mitigation guidance](https://www.intel.com/content/www/us/en/developer/articles/technical/software-security-guidance/best-practices/mitigation-strategies-jcc-microcode.html)
describes a performance mechanism in which certain branches or compare/branch
pairs crossing or ending on 32-byte boundaries cannot use the decoded
instruction cache under the mitigation. That documented mechanism makes this
placement a plausible target for a controlled experiment. It does not establish
that this specific host/run incurred that mechanism. The retained host reports
i7-9750H and microcode `0xfa`; these identifiers alone are not a counter-based
attribution. Accessed 2026-10-04.

## Reproducible evidence

[`xps-linked-loops.json`](evidence/m3-selection-code-placement/xps-linked-loops.json)
records the input hashes, exact linked symbol/loop listings, boundary spans,
normalized-loop hashes and measured anchor ratios. The inspector checks its
assembly and summary inputs against the original retained manifest and fails
on missing/ambiguous symbols or differing scalar-loop instruction shapes.

```bash
python3 tools/research/inspect_m3_selection_codegen.py \
  experiments/m3_conversion_selection/evidence/2026-10-04-xps \
  > /tmp/m3-selection-code-placement.json
cmp /tmp/m3-selection-code-placement.json \
  docs/research/evidence/m3-selection-code-placement/xps-linked-loops.json
```

Independent repeated generation is byte-exact. The original evidence manifest
and summary remain unchanged. This inspection needs Python only; it does not
require installing a different D compiler or re-running the timings.

## Next controlled experiment

First compare the existing selected form with a form that preserves an explicit
DMD-only scalar executor boundary (`pragma(inline, false)`), retaining the
same approved slices, scalar arithmetic, all validation and SIMD core. Cover
both flat and affine call sites, and keep LDC/portable unchanged. The purpose
is to make the small loop's binary identity and placement independently
inspectable, **not** to assume that no-inline is faster.

Use an additional controlled placement perturbation or independently linked
replicas to test whether the effect tracks the branch positions. Preserve
both consumers and block lengths, all 31x17 anchors and widths 63/64/65, with
original/selected/unconditional controls, full semantic/trust checks and fresh
linked listings. Where available on XPS, collect decoded-cache versus legacy
decode events using supported counters, recorded separately from timing.
Do not weaken bounds checks or alter numerical/error/overlap contracts.

Only repeated runtime evidence may select a corrected implementation. The
current candidate remains rejected for Production; no source-alignment trick,
no-inline rule or new width threshold is selected by this static step.
