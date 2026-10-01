# Generic fill consumer qualification

Research Issue #17; production baseline `d4763ff0b95999743ea43d0b1dcca44fc68773d1`.

`generate.py` verifies the clean production HEAD and SHA256 of both complete
production fill modules. Each generated candidate preserves the public wrapper,
all eight inherited tests, invalid-plane and empty behavior, and the original
Universal traversal. Only execution for sample stride one differs:

- Pointer: bounded generic signed-row/sample writes under documented trust.
- Slice: narrow trusted row construction followed by safe D slice assignment.

No destination injectivity requirement is added: repeated and overlapping rows
are valid for fill. Every logical write assigns the same exact sample value.
No persistent noalias, SIMD, compiler-specific source, or threading is added.

The complete-consumer harness has 70 cases: float and ubyte each use three
working-set sizes and ten layouts; eight-byte POD uses all ten small layouts.
Layouts cover contiguous, padded, negative rows, repeated rows, overlapping
positive/negative rows, sample stride +2/-2, zero sample stride and both strides
zero. The independent oracle checks every allocated sample, including padding
and guard regions, after every timed call. Special float checks compare signed
zero, NaN payload and infinities bitwise; invalid-plane/empty checks cover all
three types. Two warmups precede nine rounds with cyclic path order.

## Run on XPS

Place sibling checkouts of raster-d and raster-d-research at the recorded
baseline and this research head. DMD 2.111, LDC 1.41, DUB 1.40, Python 3,
objdump and taskset must be available. Use a clean production checkout;
local modifications make generation fail deliberately.

```bash
experiments/m3_fill_executor/collect.sh /tmp/fill-xps 0 xps
(cd /tmp/fill-xps && sha256sum -c SHA256SUMS)
tar -C /tmp -czf /tmp/fill-xps.tar.gz fill-xps
```

The collector builds/tests both candidates and challenges their actual trusted
source as safe for float, ubyte and POD. It retains exact verbose release build
commands, binary hashes, environment, affinity and three fixed-binary processes
per compiler. It records isolated actual-kernel disassembly to answer source-form
questions; these probes are diagnostic rather than complete-consumer causal proof.
`summarize.py` validates all raw counts, reported medians and fingerprints across
all six processes before reporting ratios and process spread.

Container timing is diagnostic. Production selection requires separate XPS
qualification; AArch64 performance remains unqualified. Raw benchmark results
must not be generalized into portable timing promises.

Tiny zero-duration samples are preserved; zero-median speedup ratios are omitted.
All large-case raw samples must be positive. The collector writes SHA256SUMS.
