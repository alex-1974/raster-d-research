# M3.5 complete public copy/conversion candidates

Research Issue #22 / PR #23 follows the baseline audit in
`../m3_copy_conversion/`. Production is pinned at
`1671fb2e51a7b1e7311f78f575d9457e9f279fd4`. This experiment compares full
public consumers; it does not provide an unchecked replacement public API.

| Path | Changes after unchanged public validation |
| --- | --- |
| public | Original production operation |
| bounds | Checked disjoint envelopes before original exact affine classification |
| execute | Safe row-slice copy / exact conversion on matching unit sample strides, including already-approved flat conversion |
| combined | Both independent changes |
| cpp | Existing separately compiled already-approved execution reference |

The generator verifies complete public/internal copy/conversion modules and
validated-affine-bounds module by SHA256, then mechanically copies them.
All three candidates retain nine public tests per operation plus 16 copy and
15 conversion dispatch tests: 147 inherited tests. The cloned bounds module
retains two inherited tests and adds two cross-type tests (5,000 independent
byte-oracle cases plus integer-limit/original-classifier controls). A harness
test exercises complete consumer failures and independent backing oracles.
Fourteen test modules contain 152 unittest blocks in total.

Bounds prove disjointness only. Overlapping or unrepresentable envelopes
preserve the exact classifier result including arithmeticFailure; original
operation-local defensive pairwise fallbacks remain unchanged. Same-type copy
reuses the qualified checked wrapper; cross-type conversion applies the same
checked envelope arithmetic separately at sample sizes one and four before
its original exact classifier. No pointer access occurs in the bounds layer.
The inherited bounded same-type oracle and new cross-type byte oracle each
cover 5,000 cases, with overlapping/disjoint outcomes and bounds-hit/decline
controls. Synthetic integer-limit addresses are never dereferenced.

Copy keeps its existing whole-plane checked memcpy flat path. Unit sample
strides in approved affine execution use row slices and D slice assignment.
Conversion uses the same safe per-row ubyte-to-float loop on approved unit
sample strides and the approved flat path. Other sample strides retain the
original checked traversal. Signed and repeated source rows remain legal;
destination injectivity is still checked. No zero-source shortcut is added.
Every float conversion is exact for all 256 ubyte values.

Only scoped row pointer arithmetic/slice construction is trusted. Complete
validated backing and prior disjointness/injectivity checks prove each row's
reachability and exclusive sample writes; slices do not escape. The loops and
copy/conversion assignments are safe/pure/nothrow/nogc. Actual-source probes
extract all four generated row-kernel instances, instantiate ubyte/float/POD
copy and exact conversion under those attributes, then require @safe row
formation to fail. The inspected C++ binding also retains its actual-source
positive/negative challenge. Those challenges supplement the safety argument.

96 timed cases cover three sizes, eight signed/strided/repeated source layouts
and four operations; 32 additional semantic cases preserve bitwise float copy,
all-256 conversion, source/destination padding and guard oracles. Every one of
four public paths receives invalid-plane, shape, non-injective, overlap/no-write
and null-base/extreme-stride empty controls. Shared backing covers both sparse
Universal and Canonical disjoint samples with overlapping envelopes, ensuring
bounds decline and exact approval before optimized row execution. Complete
shared backing is compared with an independent byte/value image.

Two warmups precede fifteen cyclic rounds across five paths, every path
occupying every order position three times. Reset, source fingerprint and
complete destination checks occur outside timing. Six fixed-binary processes
produce 43,200 timed calls. The standard-library summarizer checks all raw
samples/odd medians/case counts and cross-compiler/process hashes. Large samples
must be positive; tiny zero medians remain recorded with ratios omitted.

C++ omits public validation and adds an external C ABI call; row memcpy differs
from the public flat whole-plane memcpy. C++ ratios remain scoped execution
comparisons, while public/bounds/execute/combined ratios compare full consumers.
Isolated code generation mechanically extracts the actual row kernels and
instantiates all four operations at the recorded D release optimization levels.
Its assembly is diagnostic, not an end-to-end causal proof.
No fast-math, contraction, LTO, explicit ISA, compiler switch, manual SIMD or
threading is enabled. XPS is required for promotion; AArch64 remains unqualified.

## Collect on the reference XPS

Use clean sibling checkouts with production at the pinned commit. DMD 2.111,
LDC 1.41, DUB 1.40, G++, Python 3, objdump and taskset must be on PATH.
CXX can choose G++; the actual version/commands are retained. Both D binaries
link one common strict C++ object, and three processes per compiler use the
selected CPU. Frequency/thermal controls are unchanged and explicitly recorded.

```bash
experiments/m3_copy_conversion_candidates/collect.sh /tmp/copy-candidates-xps 0 xps
(cd /tmp/copy-candidates-xps && sha256sum -c SHA256SUMS)
tar -C /tmp -czf /tmp/copy-candidates-xps.tar.gz copy-candidates-xps
```
