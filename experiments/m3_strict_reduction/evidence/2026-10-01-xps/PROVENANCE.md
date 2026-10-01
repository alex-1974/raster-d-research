# Strict reduction XPS evidence

Uploaded archive: `raster-strict-xps-20261001-100648.tar.gz`.
Archive SHA256: `0347e01e14a3335c270c95e0ea480c12c55ecd948ddabd7fcd64a3e71291c145`.
Collector research commit: `849745341de4a87b0e535f54bf577b1af173d5fc`.
Production baseline: `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`.

All 19 files covered by uploaded SHA256SUMS pass. The uploaded SUMMARY.md was
reproduced byte-for-byte using that collector revision's summarizer before any
editorial update. All uploaded files, including its pre-decision gate wording,
are retained byte-exact; this provenance is additional and is not covered by the
uploaded manifest. The final interpretation is in docs/research/m3-strict-reduction.md.

Dell XPS 15, Intel i7-9750H, x86_64 Linux 6.17.0-22, affinity CPU 0;
frequency/thermal controls unchanged. DMD 2.111.0, LDC 1.41.0 / LLVM 19.1.7,
DUB 1.40.0; G++ 15.2.0. The VM used LLVM 20.1.5 and G++ 13.3.0:
differences between hosts cannot be attributed solely to hardware.

Both compilers pass four inherited unittest modules and both actual-source
trust challenges. All six fixed-binary processes pass 42 timed and 56 semantic
cases plus invalid/empty/out-zero/cancellation contracts. Finite result bits
and complete source fingerprints agree across all processes/compilers. NaNs
are checked by class. Raw samples, build commands, binary/object hashes and
isolated disassembly are preserved. No production implementation changes.
