# M3 counted scalar loop across controlled placements

Refs #32/#22; follows PR34's XPS placement finding. This separate Research
candidate preserves the qualified boundary/placement harness and changes only
the selected DMD scalar loop from:

```d
foreach (x, value; row)
    destination[x] = cast(float)value;
```

to:

```d
foreach (x; 0 .. row.length)
    destination[x] = cast(float)row[x];
```

The experiment asks whether DMD emits a different scalar loop whose measured
behavior is stable across entry offsets 0/8/16/24 modulo 32. No machine-code
shape or speedup is assumed. A code gate rejects a byte-identical old scalar
body; a full replay requires identical candidate bytes through first return
across all DMD modes and positions.

The two approved row slices, exact conversion arithmetic, attributes, trust,
validation and overlap fallback remain inherited. The change is inside
`vectorEnabled`'s DMD x86-64 alternative and retains `pragma(inline,false)`.
The inactive scalar declaration is preserved exactly for LDC and forced
portable builds. Original public and unconditional vector comparison forms
are unchanged. This candidate still selects SIMD at width 64 once per
operation; changing that threshold is outside this step.

## Reused controls

The adapter hash-pins `m3_conversion_boundary/collect.py` to
`b540e5c32fe36485062bf2d04f84f8f35eaefff0ff465e30ad05431dccfa26a1`, the
collector qualified at `cd293ff6443ebce0fdbeec1d2962eb85a4e13ec9`. Its parent
selection source hashes and Production pin remain checked unchanged.
The boundary harness records the adapter's own Python inputs. The indexed
collection adds explicit boundary provenance, checked during replay.

Inherited actual-source unittest, trust/attribute, full backing/bitwise/four
rounding mode, guard-page, Copy, public boundary and shared-backing gates run
for every cohort/mode. Five DMD placements and one LDC control use four modes,
six processes by default (144 processes). Expanded short/long both use the
focused 72-workload matrix, not a universal 438-case qualification. All
inherited timing budgets and round orders remain. The selected result column
is still called `selected64`; collection scope identifies the indexed study.

Actual scalar calls at both dispatchers, exact requested offsets and fixed
other function entries remain mandatory in a full cohort replay. A CI job
with one position cannot establish cross-position address or code invariance;
the combined qualification must check that separately. Source-level equality
does not establish runtime performance. Separate binary cohorts remain
unpaired; frequency/thermal conditions are not sampled.

`old-boundary-negative.txt` contains unchanged actual scalar and two dispatcher
blocks from PR34's XPS native/prior-long linked listing. Raw archive
`raster-boundary-xps-run-WRfmq6.tar.gz`, SHA256
`6e66a3b43fe608e7b91f544338ef3a1d170d6ffc936e5ff3efae17eadd35fac2`.
This fixture verifies that the new machine-code gate rejects the old preserved
body after actual-call checks pass. The older inlined candidate is also
rejected by the inherited negative control.

## Collect and replay

Use the same Linux x86-64 toolchains and clean sibling Production checkout
as PR34: DMD2.111.0, LDC1.41.0/frontend2.111.0, DUB1.40.0, GNU ld/gcc/g++,
objdump and Python3. Output must be new; assertions must be enabled.

```bash
python3 experiments/m3_conversion_indexed/check_setup.py
python3 -u experiments/m3_conversion_indexed/collect.py /tmp/conversion-indexed
(cd /tmp/conversion-indexed && sha256sum -c SHA256SUMS)
python3 experiments/m3_conversion_indexed/collect.py /tmp/conversion-indexed --replay > /tmp/indexed-replayed.csv
cmp /tmp/indexed-replayed.csv /tmp/conversion-indexed/summary.csv
```

The inherited CLI supports `--compiler dmd|ldc2|both`,
`--positions native,0,8,16,24` and `--processes 1..6`. LDC is native only.

## Status

Local source isolation, old-code rejection and GNU linker smoke checks pass.
The local environment has no D compiler. Independent six-job compiler CI
must qualify actual source semantics, changed scalar code, preserved calls
and requested positions. Hardware performance remains open. Production and
the previous experiments remain unchanged; no promotion or merge is selected.
