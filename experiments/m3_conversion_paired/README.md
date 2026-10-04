# M3 width-hybrid paired-slice loop

Refs #32/#22; follow-up to PR #36 and its XPS measurement.
This Research candidate changes only the active selected DMD scalar loop:

```d
if (width < 64)
{
    foreach (x, value; row)
        destination[x] = cast(float)value;
}
else
{
    scope const(ubyte)[] remainingSource = row;
    scope auto remainingDestination = destination;
    while (remainingSource.length != 0 && remainingDestination.length != 0)
    {
        remainingDestination[0] = cast(float)remainingSource[0];
        remainingSource = remainingSource[1 .. $];
        remainingDestination = remainingDestination[1 .. $];
    }
}
```

Widths below 64 retain the original `foreach` loop. Width 64 and above use the
paired remaining-slice loop. The threshold follows the existing width-64 SIMD
policy and targets the measured narrow-width regressions. For that loop, both
approved slices have the same validated width; each iteration checks both
remaining lengths, converts the first sample and advances both slices. No raw
pointer operation or new trust boundary is introduced. The equal slices shrink
together, so the simultaneous empty guard handles the complete row, including
zero width through the original narrow loop.

The question is whether the narrow `foreach` fallback avoids the measured
DMD losses at widths 31 and 63 while retaining the paired-loop gains at wider
sizes. Bounds checks remain enabled; actual linked code and timings decide.

## Source isolation and reused qualification

Retain the selected width-64 SIMD policy and preserved scalar boundary.
The hybrid is confined to `vectorEnabled`'s DMD x86-64 alternative. The
inactive declaration for LDC/forced portable builds remains exact. Original,
unconditional SIMD, public validation, overlap fallback, attributes, approved
borrows and exact arithmetic are inherited unchanged.

Reuse the indexed adapter, pinned to SHA256
`be0e77145fb726ad0a629f23d3d6920f38333016bbe29e39cbaf237c2ac2b9bc`,
and its qualified boundary-harness pin. The adapter is loaded with the hybrid loop literal and Research output root;
no previous experiment file is changed.
Collection records its own Python input hashes, boundary provenance and
indexed-adapter provenance. Replay requires both adapter identities.

All inherited actual-source safety/attribute/trust, unittest, full-public,
bitwise/four-rounding-mode, guard-page, Copy, selection-boundary and
shared-backing gates remain mandatory. Actual scalar calls at both dispatchers,
exact requested offsets and fixed other function entries are checked as in
PR34. The generated hybrid function must differ from the indexed scalar body; a full
replay requires identical scalar bytes through first return across DMD modes
and positions.

Native plus four DMD positions and LDC native control retain four modes,
six processes by default (144 processes). Both expanded block lengths use
the focused 72-workload matrix, not the universal 438-workload sweep. Timing
budgets, round order, backing checks and narrow C++ diagnostic scope remain
unchanged. The result column is still `selected64`; collection scope explicitly
identifies this width-hybrid variant. Cohorts are separate binaries run in
sequence, not paired observations; frequency/thermal state is unmonitored.

`old-indexed-negative.txt` contains actual unchanged scalar and two dispatcher
blocks from PR35's XPS native/prior-long linked listing, uploaded archive
`raster-indexed-xps-run-I83RE1.tar.gz`, SHA256
`3450ab11607403b93f564a3eac8fb8ddd7649349abcf52888b20dce4bcc1a89a`.
The inherited actual value-foreach and inlined negatives also run. This
confirms that source adaptation alone cannot falsely satisfy the code gate.

## Previous paired-loop measurement

The prior all-slice candidate passed compiler CI and combined replay, but its
XPS timing had a repeatable narrow-width regression. On the 72-workload sweep,
DMD was slower than the original `foreach` in 20 cases at widths 31 and 63,
across all five layouts; those cases were about 1.7–3.7× slower. Wider cases
produced a median `original_over_form` ratio of 1.14× native and 1.35× at the
controlled placements. Across DMD sweep entries, the candidate's median
`form_over_cpp` was 8.73× versus 6.46× for the original. LDC was essentially
unchanged (2.42× versus 2.41× against C++).

The uploaded XPS archive `raster-paired-xps-run-fVpVwU.tar.gz` has SHA256
`d2ddf40898598889495874b01ca190cebb017f89ab9151e5d5f97f93ae18419f`.
The hybrid follow-up tests the width fallback against the same matrix; these
numbers are motivation, not results for the hybrid.

## Collect and replay

Use Linux x86-64, DMD2.111.0, LDC1.41.0/frontend2.111.0, DUB1.40.0,
GNU ld/gcc/g++, objdump and Python3, with the same clean sibling Production
pin `7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`. Assertions must be enabled
and the output directory must be new.

```bash
python3 experiments/m3_conversion_paired/check_setup.py
python3 -u experiments/m3_conversion_paired/collect.py /tmp/conversion-paired
(cd /tmp/conversion-paired && sha256sum -c SHA256SUMS)
python3 experiments/m3_conversion_paired/collect.py /tmp/conversion-paired --replay > /tmp/paired-replayed.csv
cmp /tmp/paired-replayed.csv /tmp/conversion-paired/summary.csv
```

Inherited options: `--compiler dmd|ldc2|both`,
`--positions native,0,8,16,24`, `--processes 1..6`; LDC is native only.
Single-position CI cannot establish cross-position invariance; combined
post-download replay is required for that qualification.

## Status

The previous paired-loop candidate's CI, artifact manifests and combined
replay pass. This hybrid source adaptation has not yet passed compiler CI or
XPS timing. Hardware evidence must confirm whether it removes the narrow-width
losses without giving up wider gains. No candidate promotion, merge or
Production change.
