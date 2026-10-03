# M3.10 conservative exact-vector selection

Refs #32, #30, #28 and parent #22. PR31's qualified XPS sweep motivates a
private row-width >=64 policy, but its actual full public implementation must
be measured. Production PR61 remains pinned and unchanged at
`7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`. This standalone topic uses the
existing `research/m3-point-transform` integration baseline and assumes no
merge of earlier Research PRs. `.workspace/` is unavailable; tracked AGENTS and
supplied relevant canonical policy documents were read.

[Method, matrices and proofs](../../experiments/m3_conversion_selection/README.md)
cover the prior three-path consumer and expanded four-path/C++ consumer, each
with short and long blocks. The short sweep has 438 workloads. The long sweep
is explicitly focused: 63/64/65 at three heights and all prior anchors, 72
workloads. Separate compiled binaries, complete source/generated/assembly/
object/binary identities, six processes per compiler, bitwise full backing/
source oracles and declared iteration budgets are retained.

## Rejected wrapper selection

The initial `selected64` candidate routes DMD rows through an extra safe wrapper,
calling the unchanged exact SIMD-store kernel only for widths >=64 and retaining
the exact original foreach conversion below it. LDC/forced-portable dispatch
compiles the original expression directly; no new trusted boundary is added.
The candidate is semantically correct but fails its small-row performance goal.

[evidence/2026-10-03-wrapper-negative](../../experiments/m3_conversion_selection/evidence/2026-10-03-wrapper-negative)
preserves all four complete audits on the shared AMD EPYC VM, DMD2.111,
LDC1.41/frontend2.111/LLVM20.1.5, GCC13.3 and DUB1.40. Affinity is fixed;
frequency/thermal conditions are unmonitored. The full compiler semantics,
attributes/trust, 10,240-case bitwise/four-rounding-mode and forty-page guard
suites pass in every mode. Additional 54 full-public and eighteen shared-backing
selection-boundary cases pass, default/forced portable. Every mode has six
processes per compiler and all 438 overlapping workload fingerprints agree
across modes/compilers/processes. Summary replay and original/retained hashes
verify byte-exactly; lossless deterministic gzip bounds repository size.

| Wrapper candidate / contiguous | Prior short original/selected | Prior long | Expanded short |
| --- | ---: | ---: | ---: |
| DMD 31x17 | 1.112 | 0.998 | 0.753 |
| DMD 2048x512 | 3.606 | 4.445 | 4.131 |
| DMD 1x128 | outside prior matrix | outside prior matrix | 0.292 |

Ratios >1 favor the candidate. In the expanded short consumer, DMD 31x17
original/selected process range is 0.751–0.755: the selected operation takes
about 33% longer than original in every process. For 1x128 contiguous the
range is 0.282–0.301, roughly 3.4x original elapsed time. All sub-64 unit-stride
median ratios in that consumer are below one (0.292–0.987). Retaining scalar
expressions inside an additional helper has not retained consumer performance.
These results do not isolate call/branch/code-placement/compiler effects.

Decision: reject this wrapper policy for Production promotion. Preserve it as
measured negative evidence. Move selection directly into the existing approved
row dispatcher, so the original small-row expression executes at its original
call site rather than through an extra helper. Qualify the actual direct-dispatch
candidate in all four modes before judging the next step. The earlier PR29 XPS
31x17 regression remains relevant and is not erased by VM results.

## Evidence verification

Each mode retains the original manifest as `RAW-SHA256SUMS`, and the root
preserves its original recursive manifest under the same name. New retained
manifests cover compressed storage and nested manifests. The verifier maps the
original child manifests and decompresses original timing/assembly bytes before
checking their hashes. No compiled binary/object is checked in.

```bash
python3 experiments/m3_conversion_selection/support/verify.py experiments/m3_conversion_selection/evidence/2026-10-03-wrapper-negative
python3 experiments/m3_conversion_selection/collect.py experiments/m3_conversion_selection/evidence/2026-10-03-wrapper-negative --replay > /tmp/selection-replay.csv
cmp /tmp/selection-replay.csv experiments/m3_conversion_selection/evidence/2026-10-03-wrapper-negative/summary.csv
```

Negative parser controls reject missing rounds, duplicate blocks, wrong cyclic
forms, process relabelling, incorrect iteration budgets and missing compiler
families. Python optimized execution is rejected. Independent CI repeats both
compilers in all four consumer/block modes with one process and no timing
threshold. C++ is timed only in the expanded consumer and still omits public
validation: no equivalent full-public parity or isolated validation cost is
inferred. Remaining signed-LDC/DMD conversion work stays open.
