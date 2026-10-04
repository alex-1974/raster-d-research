# M3 bounded pointer/count row kernel

Follow-up to PR #37's width-hybrid candidate and XPS timing. This Research-only
variant keeps the hybrid dispatch: widths below 64 retain the original
`foreach`; widths 64 and above call a small DMD-only helper that walks the
validated source and destination row with local pointers and a bounded count.
LDC's preserved alternative remains unchanged.

```d
private void convertPairedPointerRow(
    scope const(ubyte)[] row, scope float[] destination)
    @trusted pure nothrow @nogc
{
    assert(row.length == destination.length);
    scope const(ubyte)* sourcePointer = row.ptr;
    scope float* destinationPointer = destination.ptr;
    foreach (i; 0 .. row.length)
        destinationPointer[i] = cast(float)sourcePointer[i];
}
```

The helper is placed only in the DMD `vectorEnabled` alternative. Its sole
call site is reached for widths at least 64, after existing validation and row
slice construction. Those slices have equal validated lengths; each pointer
index is bounded by that length, and the pointers remain local. The assertion
checks the slice invariant during assertion-enabled builds. The isolated
`@safe` replacement is required to fail, so the trust boundary is tested
independently. The bounded count loop must retain generated linked code as a
separate call; collection and replay check that call and require identical
helper machine code across DMD modes and controlled positions.

## Scope and qualification

No Production source, arithmetic, public validation, overlap handling,
attributes, approved borrows, or SIMD policy changes. The helper is confined
to the Research overlay and the DMD x86-64 branch. The width threshold and
small-width fallback are inherited from PR #37. The candidate is compared
against the hybrid baseline; the previous XPS report showed the hybrid improved
wide cases over the original but remained slower than the diagnostic C++
executor. C++ ratios are diagnostic because that executor skips part of D
validation and uses known-disjoint fixtures.

The adapter remains pinned to indexed harness SHA256
`be0e77145fb726ad0a629f23d3d6920f38333016bbe29e39cbaf237c2ac2b9bc` and its
qualified boundary harness. Existing source, linker placement, four consumer
modes, correctness, guard, backing, rounding-mode and provenance gates remain
required. Setup rejects the unchanged indexed scalar and PR #37 hybrid scalar
machine-code negatives. Full replay must show one helper call from the scalar
boundary and matching helper bytes across DMD modes and positions.

CI uses DMD 2.111.0 at native and offsets 0, 8, 16, 24, plus LDC 1.41.0 at
native as a portable-path control. Hardware measurement remains a separate
step; CI does not establish performance. The XPS run must use the same paired
72-workload sweep, five DMD placements and LDC native cohort as the hybrid
baseline, with frequency and thermal state recorded if available.

## Collect and replay

Use Linux x86-64, DMD 2.111.0, LDC 1.41.0/frontend 2.111.0, DUB 1.40.0,
GNU ld/gcc/g++, objdump and Python 3, with the same clean sibling Production
pin `7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`. Assertions must be enabled
and each output directory must be new.

```bash
python3 experiments/m3_conversion_paired/check_setup.py
python3 -u experiments/m3_conversion_paired/collect.py /tmp/conversion-pointer
(cd /tmp/conversion-pointer && sha256sum -c SHA256SUMS)
python3 experiments/m3_conversion_paired/collect.py /tmp/conversion-pointer --replay > /tmp/pointer-replayed.csv
cmp /tmp/pointer-replayed.csv /tmp/conversion-pointer/summary.csv
```

Inherited options: `--compiler dmd|ldc2|both`,
`--positions native,0,8,16,24`, `--processes 1..6`; LDC is native only.
Single-position CI cannot establish cross-position invariance; combined
post-download replay remains required.

## Status

This is an isolated experiment candidate. It needs compiler CI, combined
artifact replay and the paired XPS measurement before judging the pointer
loop. No promotion, merge or Production change.
