# M3.5 container baseline evidence

Production `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`; Research Issue #22.
The containing research commit preserves generator, unchanged diagnostic source,
harness, C++ reference, flags, collector and summary alongside these raw files.
All 18 uploaded-to-repository manifest entries verify; SUMMARY.md reproduces
byte-for-byte. This provenance is additional to the generated manifest.

AMD EPYC 9V74 KVM VM, x86_64, affinity CPU 0, frequency/thermal controls
unchanged. DMD 2.111.0; LDC 1.41.0 / LLVM 20.1.5; DUB 1.40.0;
G++ 13.3.0. Verbose release commands, object/binary hashes and C++ disassembly
are preserved. Both compilers pass three unittest modules: 16 copy and 15
conversion inherited tests plus the independent semantic/contract harness test.
Actual-source C++ wrapper challenges pass. All six fixed-binary processes pass
96 timed, 32 additional semantic and public failure/no-write/shared-disjoint
controls; all source/result fingerprints agree. Twelve cyclic rounds over
four paths yield 27,648 timed calls; resetting/checking backing is outside timers.

Public is complete; Approved, C++ and Relation are scoped diagnostics with
prior validation supplied by fixtures. Differences are not a complete-library
language comparison or a validation-preserving candidate. Diagnostic timings
are not subtracted to infer exact causal fractions. Flat public copy bypasses
the separately measured exact affine classifier and already uses memcpy.

No Production change is promoted. XPS qualification and a complete candidate
preserving failure, alias, fallback and numerical behavior are required.
