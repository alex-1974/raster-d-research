# Container fill executor evidence

Date: 2026-10-01. Research Issue #17. Production baseline
`d4763ff0b95999743ea43d0b1dcca44fc68773d1`.

Generated source is reproducible from the committed generator and the pinned
production files whose complete SHA256 digests it verifies. The research commit
containing this evidence records the generator, harness and collector together.

DMD 2.111.0, LDC 1.41.0 / LLVM 20.1.5, DUB 1.40.0; EPYC VM, affinity CPU 0.
Host frequency/thermal controls unchanged. Exact verbose build flags, environment
and fixed-binary hashes are preserved. Both inherited eight-test suites and
actual-source trust challenges pass. All six processes pass 70 full-storage
cases, invalid-plane/empty checks and bitwise special-float fill checks. All
cross-process/compiler output hashes match.

Tiny samples can be zero at this timer's resolution. The original validator
rejected such samples; its corrected committed version preserves nonnegative
samples, requires positive large-case samples and omits zero-median ratios.
No kernel/harness/binary change was needed; SUMMARY.md is reproduced from the
preserved raw logs. No rejected/partial summary is retained as timing evidence.

Container timing is diagnostic. XPS source-form selection and AArch64
performance remain unqualified. Repeated/overlapping rows perform repeated
logical writes to shared physical samples; they are not independent-memory
bandwidth measurements. No precise portable speedup is claimed.
