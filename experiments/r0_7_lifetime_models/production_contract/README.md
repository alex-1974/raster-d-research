# R0.7 production contract consumer probes

Read-only, pinned against `raster-d` merge `694c539` on `develop`.
This exercise uses the *real* exported `RasterLease`, `RasterView` and
`tryRoi` declarations, not the toy standalone research structs.

Run `bash run.sh dmd` or `bash run.sh ldc2` with git, dub and the compiler
installed. Both ordinary and `-preview=dip1000` modes are observed.
Only the well-typed, positive public consumer is a hard acceptance gate.
Negative-case outcomes must be recorded with diagnostic reasons before
claiming any static lifetime guarantee; a rejected case by itself is not
proof of escape prevention. The script also runs the pinned production's
existing `dub test` lifetime and ownership regressions.

**Limits:** This does not manufacture a post-destruction dereference, does
not claim `@safe` prevents all owner/view misuse, does not test arbitrary
cross-thread use of non-atomic retained owners, and does not replace
real-time/architecture profiling. The upstream production tree is never
modified or committed.

## Qualification: production consumer, 2026-10-10

The initial production contract workflow
[38042040286](https://github.com/alex-1974/raster-d-research/actions/runs/38042040286)
passed both DMD 2.111.0 and LDC 1.41.0 on the pinned
`raster-d` merge `694c539`; this includes the unmodified production
`dub test` suite in each job.

Observed outcomes were **identical across both compilers**:

| Probe | Ordinary | DIP1000 |
| --- | --- | --- |
| `positive` | accepted | accepted |
| `escape_return` | rejected: escaping parameter reference on return | rejected: same |
| `escape_global` | accepted | rejected: longer-lifetime global |
| `escape_closure` | accepted | rejected: local reference assigned to non-scope delegate |

Unlike the earlier toy `callback_escape`, these rejections are
lifetime-related in the compiler logs and not callback signature errors.
The ordinary-mode acceptance of global and closure escape is a
**limitation**, not evidence of safe execution.

After observing actual logs, `check_observations.py` was added as an
explicit regression gate for outcome **and diagnostic reason** at the
pinned compiler versions. Its follow-up run must pass before the
diagnostic-gated revision is considered qualified.

**Stop/no-new-API decision:** The existing lease-backed shared ownership
and cheap borrowed view remain adequate for this scope. No callback
replacement, unique-owner rewrite, atomic reference count or custom
borrow checker is justified by these compiler observations. Cross-thread
retained-handle mutation is not claimed safe. Any additional production
contract work requires a reproducible consumer-visible failure.
