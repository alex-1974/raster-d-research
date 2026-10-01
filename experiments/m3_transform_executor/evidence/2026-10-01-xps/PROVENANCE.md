# XPS upload provenance

Archive: `raster-transform-xps-20261001-082344.tar.gz`.
SHA256: `e0b5b0ec2333f69ef6e6ebe8bfd7f828db25104bd49ebbde0be6690afc9afb93`.
Research executable source: `ed7cd00ff3d91c49f732f257d2c9d10dcd11f44c`.
Production baseline: `b263477bdbbe0dc3e8c469ac3867eda345ba364c`.

All supplied checksums passed. All supplied files, including the original
SUMMARY.md, are preserved byte-for-byte. The original summarizer hardcoded the
word container; that label does not identify the uploaded machine. Environment
records identify xps-15 / Intel i7-9750H, CPU affinity 0, DMD 2.111.0,
LDC 1.41.0 / LLVM 19.1.7 and DUB 1.40.0.

QUALIFIED_SUMMARY.md is recomputed from the same raw records with an explicit
xps label using the revised summarizer. Ratios and medians are unchanged. Every
run passes 41 cases, two special-float preflights and complete output/padding
and source checks; hashes match across the six processes and both compilers.

Host frequency/thermal settings were unchanged. Some float candidate process
medians vary substantially (up to 46.56% for DMD pointer); this limits numerical
precision of a timing claim. It does not reverse the observed executor benefit
or the consistent DMD pointer-over-slice preference. No hard timing gate is
introduced from these measurements.
