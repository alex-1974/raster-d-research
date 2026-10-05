# Strict row-major float-to-double reduction

Research Issue #19. Production baseline
`1671fb2e51a7b1e7311f78f575d9457e9f279fd4`.

The generator checks clean production HEAD and full hashes of both reduction
modules, preserving the public wrapper, all nine inherited tests per candidate,
invalid/empty/out-zero behavior and original Universal traversal. Pointer and
safe row-slice candidates change only non-empty Canonical/contiguous execution.
Every path carries one double accumulator across rows in logical row-major
order. No per-row subtotals, multiple lanes or reassociation are admitted.

The C++ reference consumes already-validated geometry with the same plane-index,
out-zero, empty and strict sequential sum behavior. It omits layout/Mir
classification and adds a C ABI call; these differences limit comparison scope.
It is an execution reference, not an independent full raster library. GCC uses
`-O3 -fno-fast-math -ffp-contract=off -fno-lto` with no explicit ISA setting.

42 timed cases cover three sizes, seven layouts and positive/cancellation
corpora. An additional 56 semantic cases cover signed zeros, explicit NaN input,
infinities, subnormals and deterministic finite exponent/sign distributions.
Finite results, infinities and signed zeros are bitwise; NaNs require matching
class, not a platform-independent arithmetic payload. Source padding and guards
are checked outside each timer. Twelve samples rotate four paths through every
ordering position three times after two warmups.

## XPS collection

Use sibling production/research checkouts, with clean production at the pinned
commit. DMD 2.111, LDC 1.41, DUB 1.40, G++/GCC, Python 3, objdump and taskset
must be on PATH. CXX can select the C++ compiler; the actual version is logged.

```bash
experiments/m3_strict_reduction/collect.sh /tmp/strict-xps 0 xps
(cd /tmp/strict-xps && sha256sum -c SHA256SUMS)
tar -C /tmp -czf /tmp/strict-xps.tar.gz strict-xps
```

The collector builds one common C++ object, then both D test/release binaries;
three fixed-binary processes per compiler check all four paths. Actual-source
trust controls and isolated D/C++ disassembly are retained. The standard-library
summarizer verifies counts, even-sample medians (integer nanoseconds), result bits
and input fingerprints before reporting ratios/spread. Tiny zero durations are
retained; zero-median ratios are omitted, and all large raw samples must be
positive. It writes SHA256SUMS. Container timing is diagnostic. The completed XPS baseline audit keeps the
existing default and defers a layout-specific DMD Pointer opportunity; see
`../../docs/research/m3-strict-reduction.md`. AArch64 remains unqualified.


## Controlled DMD pointer confirmation

Issue #21 follows the qualified M3.4 XPS audit. It does **not** reopen the
strict-reduction semantics or change any candidate source. The purpose is only
to decide whether the previously observed DMD Canonical Pointer benefit is
stable enough to justify a narrow compiler-specific Production specialization.

Run the retained fixed-source harness with six independent fixed-binary
processes on one pinned CPU:

```bash
experiments/m3_strict_reduction/confirm_pointer_xps.sh \
    /tmp/raster-m3-reduction-pointer-confirm 0
```

The collector reuses the exact qualified M3.4 generator, D/C++ sources,
semantic matrix, trust challenges and codegen probes. It adds:

- six fixed-binary processes per compiler instead of three;
- CPU pinning for every timed process;
- frequency/governor and thermal snapshots before, around and after runs;
- a focused per-case public/Pointer summary;
- one recursive manifest and tar archive.

Promotion evidence is limited to representative large Canonical
padded/negative/repeated-row DMD cases. Contiguous and Universal layouts remain
controls. LDC remains a compiler control. The one-accumulator row-major
float-to-double semantic is unchanged; reassociation, fixed-lane SIMD and
threading remain out of scope.

A DMD-only Production specialization is justified only if the repeated XPS
cohort preserves a representative material gain without control regressions.
