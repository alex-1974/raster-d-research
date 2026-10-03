# Reference XPS candidate qualification — 2026-10-03

Uploaded archive: `raster-copy-xps-0ZEeBJ.tar.gz`.
Archive SHA256: `7c1636331163f30e1479f9d99bbcb230a6520b2396184f21a2fdb73f26d73ae4`.
Research collector/source: `85e1614417b628068fca071a9fa4a28ace6302e1`.
Production pin: `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`.
Separate sibling detached worktrees were requested by the supplied XPS command;
the generation pins and recorded build paths agree with that setup. No new
measurement or compiler binary was substituted during archive review.

All 19 SHA256SUMS entries verify. Original collected files remain byte-for-byte
unchanged; this note is outside the original manifest. SUMMARY.md reproduces
exactly with the pinned summarizer in xps mode. All 96 source/result fingerprints
also match the previously qualified container case identities.

Host: Dell XPS / Intel i7-9750H, x86_64, Linux 6.17.0-22-generic, CPU affinity 0;
frequency/thermal controls unchanged. DMD 2.111.0, LDC 1.41.0 with frontend
2.111.0 and LLVM 19.1.7, DUB 1.40.0, G++ 15.2.0. Container LDC used LLVM
20.1.5 and G++ 13.3.0; this is host/toolchain confirmation, not an isolated
hardware comparison. Build logs record the exact release and strict C++ flags.
Both D binaries link the same C++ object; binaries.sha256 records their hashes.

Both compilers pass 14 unittest modules / 152 unittest blocks, including 147
inherited public/dispatch blocks and bounded independent same-/cross-type
relation oracles with 5,000 cases each, plus integer-limit controls. Each has
five passing actual-source trust controls. Six fixed-binary release processes
pass 96 timed and 32 additional semantic cases, four complete public-path
contract controls, and full backing/guard fingerprints. Fifteen cyclic rounds
across five paths yield 43,200 timed calls after two warmups; reset/checks are
outside timing. Shared backing includes sparse and Canonical disjoint sample
bytes within overlapping envelopes, exercising exact fallback and row paths.

Public/candidate compares full consumers; C++ omits validation and adds a
separate C ABI call. Isolated actual row assembly is diagnostic. No explicit
SIMD, fast-math, contraction, LTO, threading or compiler switch is selected.
Large positive samples and exact odd medians pass; tiny zero medians remain
below clock resolution. High spread in short Copy cases is retained. Direction
of substantial non-flat improvements is confirmed; small Flat-Copy differences
and universal C++ parity are not established. See the audit for the scoped
promotion recommendation and remaining conversion gap.

Workspace policy attachments were available; the checkout has no .workspace
hardlinks. Tracked AGENTS.md and supplied relevant policy were used. Existing
research/m3-point-transform integration is retained for this evidence PR.
