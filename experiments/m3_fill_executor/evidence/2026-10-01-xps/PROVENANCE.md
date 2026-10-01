# XPS qualification provenance

Uploaded archive: `raster-fill-xps-20261001-090955.tar.gz`.
SHA256: `8b3271a3d6ed94cf54d8a1f6a6d5df759e99e74a02240f07ec93891a9a260d67`.
Research source `ea6fc86e12dcf442c3d99ff1dc0a8ddc04cc9c8b`;
production `d4763ff0b95999743ea43d0b1dcca44fc68773d1`.

All uploaded files are preserved byte-for-byte; every supplied checksum passes.
The committed summarizer reproduces the uploaded SUMMARY.md byte-for-byte.
All six processes pass 70 full-storage cases, bitwise special-float fills,
invalid-plane/empty checks and matching cross-compiler/process hashes.
Both candidates' inherited suites and actual-source trust challenges pass.

XPS Intel i7-9750H; CPU affinity 0; kernel 6.17.0-22-generic.
DMD 2.111.0, LDC 1.41.0 / LLVM 19.1.7, DUB 1.40.0.
Host frequency/thermal controls unchanged. Substantial process variance is
preserved. Repeated-row results concern logical writes rather than independent
memory bandwidth. Tiny cases have no precision timing claim; AArch64 is
unqualified. See the main research document for selection and tradeoffs.
