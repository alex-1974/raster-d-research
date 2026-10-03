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

Exact producer commit: `448e42657d75d1ba6c0461542aa5f46f5a5bdacd`.

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

## Rejected row-local gate

Exact producer commit: `a39247ce39238317075248b9f010391a32fe9ed5`.

A second complete six-process/four-mode audit moved the gate into the original
row executor, without calling the wrapper below width 64. It preserves the
original scalar expression at that point, but changes the generic executor's
body and still fails the prior small-row goal. In the prior short consumer,
DMD 31x17 contiguous original/selected median is 0.805 (0.785–0.809); prior
long is 0.929 (0.853–0.986). Every process takes longer than original on that
case. Large 2048x512 contiguous medians remain 4.366 / 4.402 respectively.

[evidence/2026-10-03-row-gate-negative](../../experiments/m3_conversion_selection/evidence/2026-10-03-row-gate-negative)
preserves all four full audits and their exact producer/source/generated hashes.
All semantic/trust/bitwise/guard/boundary suites pass; all original/retained
hashes and replay verify. This is measured negative evidence for the policy's
performance goal, not a semantic defect or attribution to a single compiler
mechanism. Compiler/code-placement/inlining effects remain possible.

Next candidate: select once per approved public operation, before calling a
separate safe vector-row executor. Keep the original generic scalar/copy row
executor body completely unchanged for the below-gate and portable cases.
Both flat and affine approved call sites must be covered, after their existing
physical-disjointness checks. All original validation/fallback branches and
existing row-borrow trust remain; no new trust is introduced. Qualify the
actual candidate before promotion, including every boundary/shared test and
both consumer/block-length combinations.

## Operation-level candidate

The third candidate selects once per operation at both existing approved flat
and affine conversion call sites, after their original validation and physical
non-overlap proof. On DMD x86-64, width >=64 calls a separate safe row executor
using the existing scoped row borrows and exact SIMD-store primitive. Small
operations keep the original generic executor body unchanged. LDC and forced
portable compile the original route. No additional trusted code is introduced.
Copy, fallback, errors, backing rules and public signatures remain unchanged.

The complete VM cohort is retained in
[evidence/2026-10-03-container](../../experiments/m3_conversion_selection/evidence/2026-10-03-container).
It uses the same compiler/toolchain/affinity conditions described above, four
independently compiled mode binaries per compiler and six processes each:
48 processes, 231,984 timed blocks and 308,242,584 calls. All semantics,
attributes/trust, bitwise/rounding, guard-page, public boundary and shared-backing
controls pass in every mode. Input hashes are fixed across modes; all 438
workload fingerprints agree. Original/retained manifests and byte-exact summary
replay verify.

| DMD contiguous original/selected | Prior short | Prior long | Expanded short | Expanded long |
| --- | ---: | ---: | ---: | ---: |
| 31x17 | 1.001 | 1.007 | 1.003 | 1.017 |
| 2048x512 | 4.476 | 4.455 | 4.381 | 4.520 |

In expanded short, 31x17 process ratios are 0.997–1.012. Prior long varies
0.885–1.118 despite its near-one median. All 200 wide unit-stride expanded-short
workloads favor selection in every process: median ratios 1.256–4.452, minimum
individual process ratio 1.163. The focused long sweep likewise favors all forty wide unit-stride workloads
in every process (median ratios 1.266–4.520, minimum process ratio 1.190).
This includes contiguous, padded, negative
source, negative both and repeated source; Universal stride two keeps the
existing fallback. The small expanded-short DMD median ratios span 0.968–1.305;
individual minima reach 0.791. These data remove the earlier systematic large
small-row penalties on this VM, but do not establish zero regression everywhere.
Do not interpret modest near-one differences as a qualified optimization.

LDC keeps the original route and remains near one on the large contiguous
anchors; no new LDC algorithmic gain is claimed. C++ still omits public validation.
For expanded-short 2048x512 contiguous the selected DMD/C++ median is 2.270,
LDC/C++ 1.077; at 31x17 these ratios are 7.871 and 2.224. At 2048x512 negative-source/negative-both, selected DMD/C++ medians are
2.073 / 1.909 and LDC/C++ 4.397 / 4.146 on this VM. Signed-layout and
small-call residuals remain open; these ratios cannot establish full-public
parity or isolate validation cost. Maximum spread across forms/workloads ranges 60.913–92.332% for DMD
and 57.499–136.721% for LDC across modes. Substantial process spread and unmonitored
thermal/frequency conditions limit VM claims.

Decision: retain this operation-level policy as an experimental candidate and
qualify its exact pinned producer on the XPS before Production promotion.
The 64 threshold is conservative experimental policy, not a universal optimum.
Both rejected implementations and the earlier PR29 XPS regression remain visible.
This task does not merge Research or modify Production PR61. The pinned launcher
runs all four modes on the XPS; return its complete archive for independent
hash/source/replay/fingerprint qualification before selecting the next change.

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
