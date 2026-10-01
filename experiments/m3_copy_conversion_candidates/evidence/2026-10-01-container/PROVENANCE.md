# Candidate evidence provenance

Production source: `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`.
Research baseline parent: `0b3dd8e45f7b17f26811690b8de26f26cd2033af`.
Date: 2026-10-01. Host: AMD EPYC 9V74 / KVM, affinity CPU 0;
frequency and thermal controls unchanged. Container evidence is diagnostic.

The generator verifies five full source hashes before copying complete modules;
see `generate.py` for all pins. The matrix adds conservative bounds rejection
and/or safe unit-sample-stride row execution while retaining original checks,
error ordering and defensive fallbacks. Generated sources are reproducible and
ignored. Original flat copy remains unchanged; flat conversion uses approved
rows. Universal sample-stride execution remains unchanged.

DMD 2.111.0, LDC 1.41.0 (frontend 2.111 / LLVM 20.1.5), DUB 1.40.0,
G++ 13.3.0. Exact compiler commands are in build logs. The same strict C++
object is linked into both D binaries; no fast-math, contraction, LTO, explicit
ISA, compiler switch or manual SIMD. C++ omits validation and adds an external
C ABI call, so its ratios are scoped execution diagnostics.

Both compilers pass 14 unittest modules (152 blocks including 147 inherited,
10,000 total bounded independent relation-oracle cases plus integer limits)
and five actual-source trust controls. Each of six fixed-binary processes
passes 96 timed cases, 32 extra semantic cases and public controls for all
four public paths, including sparse and Canonical shared backing with disjoint
samples inside overlapping envelopes. Complete source/output bits match.
Fifteen cyclic rounds / five paths produce 43,200 timed calls. Reset/checks
are outside timing. All large raw samples are positive; tiny zero medians
are retained without ratios.

Only the final single-collector series is included. Preliminary interrupted
series were discarded. `codegen.txt` was generated after timing finished
from the unchanged actual row source; the collector now retains the same
post-timing diagnostic. Isolated codegen is not a causal decomposition of the
complete public binary. `SUMMARY.md` reproduces byte-for-byte from raw logs.
SHA256SUMS covers 19 collected files; this provenance note is outside the
manifest. Reference XPS evidence is required before production selection.
