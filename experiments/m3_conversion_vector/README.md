# M3.8 exact DMD vector conversion

Research Issue #28 follows the measured pointer alternatives in PR #27 and
parent Issue #22. The standalone runner pins Production PR #61 at
`7dcdf01babf87e9a80af2864fbad75efe8e7d0ef` and verifies four complete source/fixture
SHA256s. It requires a clean sibling `raster-d` at this commit. No merge is
assumed. The collector derives from PR27's runner, copied here to avoid a
runtime dependency on that unmerged Research branch.

| Form | Approved conversion row on DMD x86-64 |
| --- | --- |
| original | Actual pinned safe scalar row loop |
| vector16safe | Sixteen-byte SSE2 load/unpack/conversion, safe slice result copies |
| vector16store | Same vector arithmetic, bounded unaligned SIMD result stores |

Candidates copy complete public/internal conversion modules under new internal
identities and reuse the original public error enum. Only the approved row
expression and private row kernel change. All public validation, checked
bounds, exact overlap fallback, flat selection, Universal execution, errors,
no-write/empty controls, source repeated rows and same-type Copy remain.

## Exactness and architecture

The vector branch is confined to DigitalMars on X86_64; the x86-64 SSE2 baseline
is sufficient. No AVX, SSE4, host tuning or additional ISA flags are requested.
On LDC and other compiler/architecture branches, the original safe scalar
expression remains and is free to autovectorize. `RasterForcePortable` forces
this path even on DMD x86-64. Forced portable tests are not a cross-architecture
qualification. Capability selection is contained in each private Research
kernel, with no public compiler-specific contract.

A 16-byte unaligned load is unpacked first with zero bytes into unsigned words,
then with zero words into four signed-int vectors, each containing four values
in 0..255. `CVTDQ2PS` performs numeric conversion; casting between equal-size D
vectors merely changes their bit interpretation and does not perform this
numeric conversion. Every integer is exactly representable in binary32. No
rounding error, reassociation, approximate arithmetic or fast-math is involved;
zero produces positive zero. Result groups preserve source order. Scalar tails
retain the original exact cast.

The pinned DMD druntime `core.simd` implementation and enums were inspected.
Primary references: [D vector conversions](https://dlang.org/spec/simd.html),
[core.simd intrinsics and unaligned operations](https://dlang.org/phobos/core_simd.html).
The exact supported baseline compiler, not current online docs alone, decides
which declarations and attributes compile.

## Bounds and trust proof

The private safe row kernel receives live scoped equal-length slices from the
unchanged approved dispatcher. Let n be their length. Initially x=0; each
vector iteration requires n-x >=16, so x+16 <=n without overflow. All source
and destination subslices lie inside the supplied rows; after x+=16, x<=n
remains. A tail accesses only indices x..n-1. Zero-length rows access nothing.
Assertions are diagnostics; bounds follow from the private caller and loop
also in release.

`readVectorBlock` is a tiny trusted helper with a sole safe caller supplying an
exact 16-byte subslice. `loadUnaligned` reads precisely that block, with no
alignment requirement or pointer escape. In vector16store, `writeVectorBlock`
has a sole safe caller supplying an exact four-float subslice; `storeUnaligned`
writes precisely those 16 bytes with no alignment requirement or pointer
escape. Global sample-byte disjointness, destination injectivity, reachable
backing and signed row geometry are already established by original validation.
Overlapping envelopes with disjoint samples keep the original exact fallback.
No whole-loop trust or raw public capability is introduced. vector16safe adds
only load trust; vector16store adds bounded load and store trust.

Actual-source controls preserve safe/pure/nothrow/nogc for all five row type
instantiations. Complete-helper trust removal must fail on both compilers;
DMD's active vector kernels also fail isolated removal of their new trust and
separate removal of each load/store helper's trust. LDC's inactive vector code
has no active new trust to challenge. All variants compile and run isolated
row tests in their default and forced portable selection.

Each isolated run verifies 10,240 cases: forty widths (0..33,63,64,65,255,256,257),
sixteen source byte offsets, four float offsets and four C rounding modes.
Complete source/destination guards and bitwise float comparisons include every
input byte and positive zero. Forty further widths end immediately at protected
pages, so an overread/overwrite beyond either row fails the process. Raw mapping
is fixture setup only. Separate debug inherited tests and release full public
fixtures retain 72 conversion cases and 96 unchanged Copy controls, full backing
oracles, errors/no-write/empty and shared sparse/Canonical cases. Forced portable
full public release fixtures repeat this qualification. Nine additional public
shared-backing cases (three widths 16/17/31 times three paths) activate the SIMD
load/store and scalar tails inside overlapping envelopes with disjoint samples;
default and forced portable builds pass independently.

## Runtime method and limits

Same method as PR27: eighteen workloads (31x17,256x128,2048x512; contiguous,
padded, negative source, negative both, Universal sample stride two, repeated
source rows). All three paths warm up eight times. Nine rounds use cyclic path
order `(position+round+process)%3`. Each block performs 8..4096 full public calls,
targeting 8,388,608 samples. Validation and return/error handling are timed;
allocation, writable-view construction, resets, complete backing/source oracles
and logging are outside timing. Every block emits an independently checked
fingerprint.

Six processes per compiler reuse one fixed binary; runner/children use the first
available CPU. Versions, exact commands, CPU/affinity, raw blocks, fixed binary
identity, source/generated hashes, selected public/linked assembly, controls,
summary and checksum manifest are retained. Frequency/thermal conditions are
unchanged and unmonitored; placement sweeps/cooling controls are absent. This is
shared-container evidence. Imported-unit `-i` builds differ from separately
built DUB consumers. Full object hashes identify captured files and may vary
with temporary paths. No C++ executor is timed here; historical C++ ratios
cannot be divided by these speedups to claim current parity. XPS qualification
and any Production promotion remain separate gates.

Summary: nine-round median per process, then median of process medians. Ratio
original/form is paired by process; larger means faster. Spread is process
median range divided by their median. CI uses one process and semantic gates,
with no timing threshold.

## Reproduce / XPS collector

Linux, Python 3, objdump, DMD 2.111.0, LDC 1.41.0 and DUB 1.40.0 are required on
PATH. Resolve the pinned Production DUB dependencies first.

```bash
python3 experiments/m3_conversion_vector/audit.py /tmp/conversion-vector
(cd /tmp/conversion-vector && sha256sum -c SHA256SUMS)
python3 experiments/m3_conversion_vector/summarize.py /tmp/conversion-vector > /tmp/replayed.csv
cmp /tmp/replayed.csv /tmp/conversion-vector/summary.csv
```

`--compiler dmd|ldc2|both`, `--processes 1..6`; output must be new. `collect.sh`
runs both families with six processes, verifies checksums and creates a compressed
XPS evidence archive. The qualified uploaded XPS result is retained under `evidence/2026-10-03-xps/`;
see the findings for scoped gains, variability and the small-flat regression.

[Findings and next gate](../../docs/research/m3-conversion-vector.md).

## Pinned local-XPS launcher

`run_xps.sh` prepares detached sibling worktrees from existing local repositories;
it never checks out a user's working branch or cleans a user's files. It pins
the audited experiment source commit `a38fd30c16a395f9b0d6eab3e51cb06131a3ce50`
and Production PR61 commit `7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`.
Missing objects are fetched from the existing repository's origin by exact SHA.
The launcher itself can be taken from a later PR29 head without changing this
qualified source baseline.

```bash
bash experiments/m3_conversion_vector/run_xps.sh "$HOME/Programmiersprachen/dlang/d-geospatial-workspace/libs"
```

Requires the baseline compiler/DUB versions on PATH; LLVM backend identity is
recorded rather than forced to the container build. On Linux x86-64 it runs both
compilers and six processes, preserves original collector files/manifest, records
launcher logs, full tool versions and resolved dependencies, verifies summary
regeneration and the extended manifest, then prints `UPLOAD: /tmp/...tar.gz`.
Supplementary files and the original `audit-SHA256SUMS` are included in the
archive; its extended manifest has five more entries than the original collector
manifest. Worktrees and partial evidence remain available on failure or success.
Frequency/thermal controls are unchanged. Use the actual reference XPS, close
heavy background workloads and keep power conditions consistent.

A second argument `--prepare-only` checks tools/pins and prepares worktrees,
without running a benchmark or claiming hardware qualification. It is the local
launcher smoke check, not evidence of an XPS measurement.
