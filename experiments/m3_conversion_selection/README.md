# M3.10 conservative exact-vector selection

Refs #32, #30, #28 and parent #22. This standalone study derives from PR31 at
`c8ff5dfe2d50eb2553a8e1f901992df88db426d6`, keeping Production PR61 pinned at
`7dcdf01babf87e9a80af2864fbad75efe8e7d0ef` and its four complete source/fixture
hashes. No Production change or merge is assumed.

## Actual selection and trust

The public selected form chooses once per approved operation on DMD x86-64.
Both flat and affine conversion call sites select a separate safe vector-row
executor when width >=64, after their existing bounds and physical-disjointness
checks. That executor borrows rows through the existing approved row helpers
and calls `convertVectorRow`. The original generic scalar/copy row executor
body stays unchanged for small widths and LDC/forced-portable branches.
All public validation, overlap fallback, injectivity, errors, no-write, empty
and Universal contracts remain unchanged.

`selected64.d` contains the exact qualified bounded SIMD-store kernel renamed
`convertVectorRow`, plus `convertApprovedRow` for isolated row controls. That
wrapper exercises the threshold independently; the full public selected path
uses the operation-level gate described above. The unconditional store form
and C++ reference are copied byte-exact from PR31.

The gate and executor add no trust. Existing scoped sixteen-byte load and
four-float store proofs remain unchanged. Width >=64 chooses the route; the
vector loop independently requires sixteen remaining samples, with safe scalar
tails. Unchanged expressions and helper bodies do not promise identical binary
layout or timing. Both consumers must measure the actual candidate.

## Two consumers and two block lengths

| Mode | Workloads | Forms | Samples/block target |
| --- | ---: | --- | ---: |
| prior-short | 18 prior anchors | original / selected64 / unconditional store | 262,144 |
| prior-long | 18 prior anchors | same three paths | 8,388,608 |
| sweep-short | full 438-workload PR31 matrix | same three + C++ approved execution | 262,144 |
| sweep-long | 72 focused workloads | same four paths | 8,388,608 |

Prior anchors use 31x17,256x128,2048x512 and six layouts. Focused long sweep
uses widths 63/64/65 at heights 1/17/128 plus all eighteen prior anchors; every
shape uses contiguous, padded, negative source, negative both, Universal stride
two and repeated-source rows. This makes boundary/old-regression long-block
qualification practical without claiming the complete 438-case long sweep.
`matrices.json` declares every workload before collection.

The prior source shape/order derives from PR29's timing driver; the expanded
consumer from PR31. The selected form replaces their former safe-copy alternative.
These are controlled new consumer binaries, not reproductions of old binary
layout or an attribution of the earlier 31x17 XPS conflict. Each mode builds
separately, records generated source/assembly/object/binary hashes, and reuses
its fixed binary for six processes. Order is cyclic per round/process, with
nine rounds and eight warmups per form; calls/block are 8..4096. Allocation,
resets/logging and full backing/source bitwise oracles are excluded from timing;
complete public validation/return handling are included on all three D paths.
CPU affinity is pinned; frequency/thermal state remains unmonitored.

`original_over_form` >1 favors that form. `unconditional_over_form` >1 means
that form is faster than unconditional stores. Both are paired by process after
round medians. C++ ratio columns are blank in the prior consumer. In the sweep,
`form_over_cpp` >1 means the full D public call takes longer than the separately
compiled approved executor. C++ skips public view/injectivity/physical-overlap/
error validation and uses known-disjoint restrict-qualified fixture arrays;
its ratios are scoped diagnostics, not equivalent full-public parity. GCC flags
remain baseline x86-64/generic, O3, no fast math/native tuning/LTO.

## Qualification

Every mode repeats 40 imported unittest modules; 72 original conversion backing
cases +96 Copy controls, default/forced portable; **54 additional full-public
boundary cases** at widths 63/64/65; and **18 shared-backing cases** at widths
16/17/31/63/64/65, activating both sides of the gate and the vector tail inside
overlapping envelopes with physically disjoint samples. Shared geometry uses
512-byte source/128-float destination rows and separate byte locations.

Actual-source attributes, original/selected/unconditional whole-helper trust
removal, isolated new-kernel trust and independently removed load/store trust
are challenged. Each form/selection passes 10,240 bitwise widths/offsets/four
rounding-mode cases and forty protected-page widths; 63/64/65 exercise the
actual selected wrapper. The unchanged C++ object separately passes the same
bitwise/guard suites with each D compiler and actual bridge trust removal.
It is timed only in the expanded consumer. Selected and vector core function
sections are retained, including their actual linked assembly.

Replay enforces the declared compiler families, matrix, cyclic path order,
process filename/identity, every unique round/form, exact iteration budget and
complete fingerprints. Collection checks fingerprints across all four modes,
source input immutability, byte-exact per-mode summaries, and a recursive root
manifest. CI uses one process, never timing thresholds.

## Reproduce

Linux x86-64, DMD2.111/LDC1.41/frontend2.111, DUB1.40, Python3, GCC g++, objdump,
and resolved pinned Production dependencies in a clean sibling are required.

```bash
python3 experiments/m3_conversion_selection/collect.py /tmp/conversion-selection
(cd /tmp/conversion-selection && sha256sum -c SHA256SUMS)
python3 experiments/m3_conversion_selection/collect.py /tmp/conversion-selection --replay > /tmp/selection-replay.csv
cmp /tmp/selection-replay.csv /tmp/conversion-selection/summary.csv
```

`--compiler dmd|ldc2|both`, `--processes 1..6`; output must be new. Individual
`audit.py` modes accept `--profile prior|sweep --block short|long`. The long sweep
scope remains focused and explicit. Python optimized execution is rejected.
The pinned XPS launcher is added after the qualified source commit exists.

[Findings and decision gates](../../docs/research/m3-conversion-selection.md).
