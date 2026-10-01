# M3.5 complete public copy and exact conversion baseline

Research Issue #22; production `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`.
This is a baseline/cost audit, not a validation-preserving optimization candidate.
The generator verifies clean production HEAD and full SHA256 of both public and
internal modules. It copies the complete internal modules, preserves 16 copy
and 15 conversion inherited tests, and adds diagnostic wrappers calling their
unchanged private approved traversal and exact relation functions. One harness
unittest adds public failure/no-write/shared-backing and 32 semantic cases.

| Timed path | Work and limitations |
| --- | --- |
| public | Complete current public consumer; flat copy includes checked memcpy, flat conversion the Mir scalar path |
| approved | Unchanged checked per-sample semantic traversal, fixture supplies prior approval; flat copy deliberately does not measure memcpy here |
| cpp | Execution-only row memcpy when copy sample strides are one, otherwise byte-preserving sample copies; exact ubyte-to-float loop; no D validation, external C ABI call |
| relation | Unchanged exact affine classifier plus stride/base retrieval; no writes, not full public validation |

Public/C++ ratios are opportunity diagnostics, not complete-library language
comparisons. Public minus relation or approved time is not an isolated causal
measurement: their paths, inlining, cache history and validation differ.
Any candidate selected later must retain the full public validation, exact
sample-byte alias/error/empty semantics and independently qualify XPS.

96 timed cases: three sizes (31x17, 256x128, 2048x512), eight layouts and four
operations (same-type ubyte/float/eight-byte POD copy and ubyte-to-float).
Layouts: contiguous, padded, negative source, negative both, Universal +2/-2,
repeated source rows and zero source strides; destinations are injective.
An independent storage-index oracle verifies every destination/padding/guard,
bitwise float representations (NaN payloads, signed zero, infinities/subnormal)
and all 256 conversion inputs in injective-source cases. Source backing is
fingerprinted after every call. Repeated/zero mappings use final populated
physical values and count logical work, not independent bandwidth.

Public semantic controls reject invalid planes, shape mismatch, non-injective
destination and actual overlap before writes; valid empty null-base/extreme-
stride planes succeed, invalid empty plane fails. Shared sparse same-type and
cross-type fixtures allow disjoint sample bytes despite overlapping envelopes,
with the complete backing compared to an independent expected byte image.
C++ is an already-approved execution reference and is not asked to implement
these public failures. Its inspected private trusted binding is scoped,
no-retention and bounded by the fixture geometry; an actual-source positive
control instantiates all four operations, then @safe replacement must reject
pointer casts/@system calls. Existing production trust boundaries are unchanged.

Two warmups and twelve cyclic rounds put four paths in each ordering position
three times. Destination reset and complete checks are outside timing. Three
fixed-binary processes per compiler give 27,648 timed calls. Integer-nanosecond
even medians and every raw sample are retained; tiny zero medians have no ratio.
All large execution samples must be positive; relation may be below resolution.

## Collection

Sibling production/research checkouts are required. DMD 2.111, LDC 1.41, DUB
1.40, G++, Python 3, objdump and taskset must be on PATH. CXX can select the
C++ compiler; its actual version is logged. One strict non-LTO C++ object is
linked into both D binaries. Exact commands, hashes, tests, trust diagnostics,
raw timings, disassembly and verified summary are checksummed.

```bash
experiments/m3_copy_conversion/collect.sh /tmp/copy-conversion-xps 0 xps
(cd /tmp/copy-conversion-xps && sha256sum -c SHA256SUMS)
tar -C /tmp -czf /tmp/copy-conversion-xps.tar.gz copy-conversion-xps
```

VM results are diagnostic. Frequency/thermal controls remain unchanged;
recorded versions/backend differences limit cross-host conclusions. No
production selection, explicit SIMD, threading or AArch64 qualification is
implied by this baseline. Existing research integration base is retained.
