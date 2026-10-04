# M3 paired remaining row slices

Refs #32/#22; follows PR35's qualified negative indexed-loop result.
This Research candidate changes only the active selected DMD scalar loop:

```d
scope const(ubyte)[] remainingSource = row;
scope auto remainingDestination = destination;
while (remainingSource.length != 0 && remainingDestination.length != 0)
{
    remainingDestination[0] = cast(float)remainingSource[0];
    remainingSource = remainingSource[1 .. $];
    remainingDestination = remainingDestination[1 .. $];
}
```

Both approved row slices have exactly the same validated width. Each iteration
checks both remaining lengths, reads and writes their first sample, then
advances both slices. There is no new raw pointer operation or trust boundary.
The simultaneous empty guard therefore executes the complete row, including
the zero-width case. It does not introduce a reachable truncating conversion:
both slices originate from the same `width` argument and shrink together.

The question is whether DMD emits a useful safe loop shape and whether its
measured behavior is stable across ordinary and controlled placements. Bounds
checks are not disabled. Slice syntax does not imply their elimination, a
smaller instruction count or a speedup; actual linked code and timings decide.

## Source isolation and reused qualification

Retain the selected width-64 SIMD policy and preserved scalar boundary.
The new loop is confined to `vectorEnabled`'s DMD x86-64 alternative. The
inactive declaration for LDC/forced portable builds remains exact. Original,
unconditional SIMD, public validation, overlap fallback, attributes, approved
borrows and exact arithmetic are inherited unchanged.

Reuse the indexed adapter, pinned to SHA256
`be0e77145fb726ad0a629f23d3d6920f38333016bbe29e39cbaf237c2ac2b9bc`,
and its qualified boundary-harness pin. The adapter is loaded with the new
loop literal and Research output root; no previous experiment file is changed.
Collection records its own Python input hashes, boundary provenance and
indexed-adapter provenance. Replay requires both adapter identities.

All inherited actual-source safety/attribute/trust, unittest, full-public,
bitwise/four-rounding-mode, guard-page, Copy, selection-boundary and
shared-backing gates remain mandatory. Actual scalar calls at both dispatchers,
exact requested offsets and fixed other function entries are checked as in
PR34. New code must differ from both the value-foreach and indexed scalar
bodies; a full replay requires identical new scalar bytes through first
return across DMD modes and positions.

Native plus four DMD positions and LDC native control retain four modes,
six processes by default (144 processes). Both expanded block lengths use
the focused 72-workload matrix, not the universal 438-workload sweep. Timing
budgets, round order, backing checks and narrow C++ diagnostic scope remain
unchanged. The result column is still `selected64`; collection scope explicitly
identifies this paired-slice variant. Cohorts are separate binaries run in
sequence, not paired observations; frequency/thermal state is unmonitored.

`old-indexed-negative.txt` contains actual unchanged scalar and two dispatcher
blocks from PR35's XPS native/prior-long linked listing, uploaded archive
`raster-indexed-xps-run-I83RE1.tar.gz`, SHA256
`3450ab11607403b93f564a3eac8fb8ddd7649349abcf52888b20dce4bcc1a89a`.
The inherited actual value-foreach and inlined negatives also run. This
confirms that source adaptation alone cannot falsely satisfy the code gate.

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

Local source isolation, both actual old-code negatives, Python syntax,
workflow YAML and GNU linker smoke controls pass. Local D compilers are
unavailable; independent six-job CI must qualify actual source semantics,
changed machine code, preserved calls and inherited gates. Hardware
performance is open; no candidate promotion, merge or Production change.
