# Strict reduction container evidence

Production baseline `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`.
Research Issue #19; the containing research commit records the pinned generator,
harness, C++ source, build flags, collector and summary together.

EPYC VM, CPU affinity 0, unchanged host frequency/thermal controls.
DMD 2.111.0; LDC 1.41.0 / LLVM 20.1.5; DUB 1.40.0;
GCC/G++ 13.3.0 (Ubuntu). Verbose commands and object/binary hashes are retained.
Both generated candidates inherit nine tests each across public and internal
modules; both compilers pass four unittest modules. Actual-source trust
challenges pass. All six processes pass 42 timed and 56 extra semantic cases,
invalid/empty/out-zero/cancellation contracts and source fingerprints. All
finite result bits and input hashes match across processes and compilers.

C++ is a separately compiled, non-LTO strict execution reference with explicit
invalid/empty handling, not an independently audited full raster library. It
omits D layout/Mir adaptation and adds a C ABI call. Neither difference is
silently presented as equal abstraction overhead. NaNs are checked by class,
not a portable arithmetic-result payload promise. Finite results, infinities
and signed zeros are compared bitwise. Source padding/guards are fingerprinted.

No material stable VM gain justifies a Production executor change. XPS reference
qualification remains open; no AArch64 or portable timing claim is made.
