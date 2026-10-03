# M3.7 bounded pointer-row conversion

Research Issue #26 continues #22 and the codegen-only audit in PR #25.
The collector pins the complete public Production PR #61 proposal at
`7dcdf01babf87e9a80af2864fbad75efe8e7d0ef` and four full source/fixture SHA256s.
A clean sibling `raster-d` at this commit is required. No merge is assumed.

| Form | Approved conversion row |
| --- | --- |
| original | Actual public source, safe slice loop |
| pointer | Count-bounded pointer iteration, direct exact float cast |
| pointer32 | Same iteration, exact int cast before float |

Candidate generation derives from PR25's standalone audit, preserved here
without depending on that unmerged branch. Full public/internal modules are
copied under new internal module identities, reusing the original public error
enum. Only the approved conversion row expression and a private helper change.
The safe row dispatcher, Copy execution, all public checks, flat selection,
Universal execution, exact overlap fallback, errors/no-write and empty behavior
remain. No SIMD, ISA switch, C++ reference or Production source change is added.

## Additional trust proof

The new private `convertApprovedRow` takes two live scoped slices of equal
length. Each dereference occurs while the loop index is less than that length;
the final increments form only legal one-past pointers. Empty rows dereference
nothing. No pointer or slice escapes. Its only caller is the existing approved
row dispatcher: retained backing, reachable row slices, unit sample strides,
injective destination and global sample-byte disjointness have already been
validated. Overlapping bounding envelopes do not imply sample overlap; the
original exact fallback still handles those cases. A debug assert checks equal
length, which the private caller guarantees in release too. The proof does not
rely on assertions remaining enabled. Both casts are exact for ubyte 0..255.

The helper adds trust for per-sample dereference/iteration, beyond the existing
row-formation trust. This is a Research candidate requiring measured benefit,
not permission to broaden Production trust. Actual-source attribute controls
retain safe/pure/nothrow/nogc for all five row instantiations. Removing trust
must fail both for the complete helper set and for the new helper in isolation.
Isolated executable controls cover widths 0,1,15,16,17,31,255,256,257, all byte
values, unchanged sources and complete guards. Separate debug inherited tests
and release public fixtures cover 72 conversion backing cases, 96 unchanged
Copy controls, error order/no-write/empty and shared sparse/Canonical backing.

## Runtime measurement

`timing.d` is appended to the adapted pinned fixture. Every measured call uses
the complete public operation. Three sizes (31x17, 256x128, 2048x512) and six
layouts (contiguous, padded, negative source, negative both, Universal sample
stride two, repeated source rows) form 18 workloads. Allocation, writable-view
construction, output reset, logging and complete backing/source oracles occur
outside timing. Public per-call validation and return/error handling are timed.

Each workload warms all three paths eight times, then measures nine rounds in
cyclic order `(position+round+process)%3`. Blocks perform between 8 and 4096
calls, targeting 8,388,608 samples. Every block checks complete source/destination
backing and emits its result fingerprint. Six fresh processes use the same
binary per compiler; the runner pins itself and children to the first available
CPU and records the original affinity and host. Frequency/thermal controls are
unchanged and not sampled. This is a shared container, with no placement sweep
or controlled cooling. Small differences are not qualified for promotion.

The summary takes nine-round medians per process, then the median across
processes. Ratio is original/form paired by process; spread is the range of
process medians divided by their median. Larger ratios mean a faster candidate.
Raw 486 blocks per process, versions, commands, fixed binary identity, source
pins, generated-source hashes, selected wrapper/canonical and linked assembly,
positive/negative controls and a checksum manifest are retained. Objects and
binaries stay in scratch; absolute temporary paths can change their hashes.
Imported-unit `-i` builds differ from separately built DUB libraries, and the
universal selector/switch overhead is shared by all forms. These limits also
apply to interpreting selected assembly. No C++ parity or XPS speed claim
follows from this experiment.

## Reproduce

Put DMD 2.111.0, LDC 1.41.0, DUB 1.40.0, Python 3 and objdump on PATH. Resolve
Production's pinned DUB dependencies first. Linux affinity APIs are required.

```bash
python3 experiments/m3_conversion_pointer/audit.py /tmp/conversion-pointer
(cd /tmp/conversion-pointer && sha256sum -c SHA256SUMS)
python3 experiments/m3_conversion_pointer/summarize.py /tmp/conversion-pointer > /tmp/replayed.csv
cmp /tmp/replayed.csv /tmp/conversion-pointer/summary.csv
```

`--compiler dmd|ldc2|both` and `--processes 1..6` support CI and diagnostics.
CI uses one process for semantic qualification, without speed thresholds.
`collect.sh` runs both compiler families and six processes, verifies the
manifest, and produces a compressed XPS evidence archive for upload.
Output directories must be new.

[Findings](../../docs/research/m3-conversion-pointer.md).
