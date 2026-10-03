# M3.6 full public exact-conversion codegen audit

Research Issue #24 continues remaining conversion work in Issue #22.
Production PR #61 is the source proposal, pinned at
`7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`. No Production merge is assumed.
`audit.py` requires a clean sibling `raster-d` checkout at that exact commit;
it verifies four complete source/fixture hashes before generating candidates.

| Form | Change after unchanged validation and row formation |
| --- | --- |
| original | Actual public production proposal |
| signed | Per-sample exact cast goes through int before float |
| array | Safe D array expression destination[] = row[] + 0.0f |

Both alternatives copy complete public and internal conversion modules. Only
module/import identities, reuse of the original public error enum and the
one row expression change; each retains nine public and fifteen internal
unittest blocks. Bounds, exact fallback, Universal execution, flat selection,
error ordering, no-write/empty/injectivity and scoped geometry remain.

All ubyte values 0..255 are exactly representable in int and binary32. Adding
positive float zero is exact on this domain, including positive zero. The array
form is specific to exact ubyte-to-float conversion; it is not permission to
reassociate arbitrary floating-point operations. No whole-loop trust, new
ownership/alias capability or raw public API is added.

The C ABI diagnostic wrapper accepts existing views/plane zero and calls the
complete public operation. Release builds with DIP1000 and compiler -i include
the dependent implementations in relocatable objects. This is actual public
source codegen, but its imported-unit packaging and wrapper differ from a
final separately built DUB consumer. It is not a runtime benchmark. Keep
selected wrapper/public-dispatch/canonical assembly and full object/assembly
identity hashes; reproducible scratch full objects/disassembly are discarded.
Commands and exact compiler versions are retained. Absolute temporary paths
may change object bytes on replay; full hashes identify this run, not a promise
of bit-identical future artifacts.

Debug inherited unittest builds are separate from release fixture execution.
The package-local backing fixture derives mechanically from production's pinned
integration driver: 72 public conversion cases (three forms, three sizes,
eight layouts) plus 96 unchanged Copy controls. Independent complete backing,
float bit patterns, all-256 byte corpus, padding/guards, sparse/Canonical shared
samples inside overlapping envelopes, error/no-write/non-injective and
null/extreme-stride empty controls remain. Copy is an unchanged control,
not a measured candidate. Actual-source positive controls retain
safe/pure/nothrow/nogc for ubyte/float/POD/static-array Copy and conversion;
replacing row trust with safe must fail for every form and compiler.

Run with DMD 2.111.0, LDC 1.41.0, DUB 1.40.0, Python 3 and objdump on PATH:

```bash
python3 experiments/m3_conversion_codegen/audit.py /tmp/conversion-codegen
(cd /tmp/conversion-codegen && sha256sum -c SHA256SUMS)
```

`--compiler dmd` or `--compiler ldc2` runs one family (used by targeted CI).
Output directories must be new. Dependencies are resolved by the pinned
Production DUB configuration. No timings, compiler switch, explicit SIMD,
threading or architecture performance qualification is selected from assembly.

[Findings and scoped decisions](../../docs/research/m3-conversion-codegen.md)
retain the actual diagnostics and next research gate.
