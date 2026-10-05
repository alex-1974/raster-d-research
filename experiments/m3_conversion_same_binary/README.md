# M3 same-binary Hybrid versus pointer diagnostic

Refs #39/#22. This follows PR #38 and the retained XPS pointer-vs-Hybrid
comparison. That comparison showed only a small DMD pointer advantage at width
64 and above, while the magnitude moved with binary placement and repeat pair.

## First same-binary control

The first CI version put replicated Hybrid and Pointer functions in one
executable. That was still not layout-neutral enough: under DMD 2.111.0, widths
31 and 63 execute identical scalar source yet showed pooled
Hybrid/Pointer medians about 1.39x and 1.69x. Individual replicated pairs moved
materially as well. LDC's identical-source controls also moved by pair.

That negative control is intentionally retained. It demonstrates that merely
sharing an executable does not remove function-placement effects.

## Shared-entry diagnostic

The primary diagnostic now adds two non-inlined shared entry functions. For
each function, both logical forms use the same entry address and the same caller.
Widths below 64 return through exactly the same scalar path before the runtime
form selector is inspected. At width 64 and above:

- shared pair 0 maps selector 0 to Hybrid and selector 1 to Pointer;
- shared pair 1 reverses that mapping.

Reversing the selector branch provides a taken/fallthrough control without
changing the logical algorithms. The older four separate-entry pairs remain as
an explicit placement-sensitivity control.

The two wide bodies are unchanged from the preceding research:

- Hybrid: paired remaining safe slices;
- Pointer: bounded local pointer/count traversal.

Both operate on the same validated equal-length slices. Pointer indexing is
confined to the Research-only trusted helper; no Production API or
implementation changes.

Each comparison alternates measurement order by repetition and reports medians
from 17 samples after four warmups. CI builds one release executable per
compiler, records its SHA256 and linked symbol addresses, then runs that exact
binary six times. DMD 2.111.0 is primary; LDC 1.41.0 remains a compiler/layout
control.

## Qualification rule

Do not promote the pointer form from this diagnostic alone. A full-public
follow-up is justified only if the **shared-entry** result satisfies all of the
following:

1. widths 31/63 remain near unity in both shared selectors, establishing that
   identical-source timing is no longer dominated by placement;
2. width >=64 favors Pointer repeatably in both reversed selector mappings;
3. the wide advantage is materially larger than the narrow control spread;
4. six repeated processes preserve the direction; and
5. the LDC control does not expose a comparable unexplained shift.

The separate-entry numbers are diagnostic controls, not promotion evidence.

If the shared-entry conditions fail, close the pointer source form as
non-actionable placement-sensitive evidence and continue with another
explanation for the remaining DMD conversion gap.

## Run

```bash
dub run \
  --root=experiments/m3_conversion_same_binary \
  --compiler=dmd \
  --build=release \
  --force
```

For XPS qualification, build once and run the same binary at least six times.
Preserve the executable hash, compiler version and `nm -n` output with the
cohort. No XPS run is warranted until compiler CI validates the shared-entry
control.
