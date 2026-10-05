# M3 full-public shared-boundary DMD pointer candidate

Refs #41/#39/#22. Production baseline is the merged M3.5 commit:

```text
10549e045bfa5a99afe6552b0fb41b76fe203fa5
```

PR #40's reference-XPS same-entry row diagnostic established a large DMD-only
loop-form signal after removing the separate-function placement confound.
This experiment now moves that hypothesis back through the complete public
conversion operation.

## Candidate

The experiment generates one Research-only copy of the current public
`tryConvertUbyteToFloatPlane` operation and its internal dispatch directly
from the pinned Production sources. Both measured forms enter the same public
function and traverse the same validation, error ordering, injectivity,
checked affine bounds, exact overlap fallback, empty/no-write handling and
approved row borrowing.

A Research-only selector is set **outside** the timed public call:

- form 0: current Production row conversion;
- form 1: DMD x86-64, width >=64 uses the bounded pointer/count row body;
- width <64 retains the current row loop;
- LDC always retains the current row loop.

The selector is not a Production API proposal. It exists only so current and
candidate execution can share one public entry and one generated validation
body inside the same binary.

The pointer helper receives already-approved equal-length row slices. It keeps
both pointers local, indexes only `0 .. row.length`, and is the only new
trusted operation. An isolated negative challenge must reject an `@safe`
replacement.

## Gates

Before hardware timing:

1. pinned Production source identity must match;
2. DMD 2.111.0 and LDC 1.41.0 Production unittests pass;
3. both selector values pass independent full-backing conversion cases,
   error/no-write/empty/shared-backing controls and widths 63/64/65;
4. LDC candidate selection is confirmed inactive;
5. DMD pointer-helper trust removal fails for the intended pointer-indexing
   reason;
6. one generated public entry is used by both timing forms.

Only after those gates pass is a reference-XPS full-public comparison useful.
No Production promotion follows from the isolated row result alone.


## Reference-XPS collector

After CI is green, update the local Research branch and the Production sibling
to the pinned commits, then run:

```bash
bash experiments/m3_conversion_full_public_pointer/run_xps.sh
```

The collector builds one release binary per compiler, verifies the complete
public-control mode, then reuses that exact binary for six CPU0-pinned
short-block and six CPU0-pinned long-block processes. It retains compiler,
binary and symbol identities, raw process output, semantic fingerprints,
summaries and a recursive SHA256 manifest, then produces a tar.gz archive.

The timing ratio is `current_over_pointer`; values above 1 favor the DMD
pointer candidate. Widths 31/63 and Universal sample-stride-two layouts are
controls because the candidate route must remain inactive there. LDC is a
compiler control and must retain current Production row execution.
