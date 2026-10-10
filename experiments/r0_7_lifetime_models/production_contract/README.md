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
