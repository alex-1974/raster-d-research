# Generic fill executor — container evidence

Baseline: `d4763ff0b95999743ea43d0b1dcca44fc68773d1`.

All six independent processes pass 70 cases and special-float bit checks; all hashes match across processes and compilers. Invalid-plane/empty checks pass for float, ubyte and POD. Each case has two warmups and nine timed calls per path, with cyclic order and full output/padding checks outside timing.

Large (2048x512) baseline/candidate median ratios across three processes, including contiguous, padded, negative, repeated and overlapping Canonical rows:

| Type | Compiler | Pointer speedup range | Slice speedup range | Max public / pointer / slice median spread |
| --- | --- | --- | --- | --- |
| float | dmd | 9.649–11.563x | 13.819–24.339x | 10.05% / 10.27% / 23.25% |
| float | ldc | 8.439–23.793x | 7.037–23.823x | 11.23% / 15.28% / 42.40% |
| ubyte | dmd | 18.949–22.359x | 91.838–438.035x | 6.08% / 10.82% / 47.97% |
| ubyte | ldc | 49.782–180.144x | 61.563–180.144x | 13.28% / 44.36% / 33.93% |

Container/VM timing is diagnostic evidence, not XPS or AArch64 qualification. Small workloads and Universal fallback have no tight timing threshold. Pointer versus slice selection and production admission require a separate review of stable reference-machine evidence.

Tiny cases can be below clock resolution: zero raw samples are retained and zero-median ratios are omitted. All large-case samples must be positive.

## Per-case paired ratios

| Case | Compiler | Pointer range | Slice range |
| --- | --- | --- | --- |
| type=float w=31 h=17 layout=contiguous | dmd | 10.333–10.667x | 15.500–16.000x |
| type=float w=31 h=17 layout=contiguous | ldc | below clock resolution | below clock resolution |
| type=float w=31 h=17 layout=padded | dmd | 10.333–10.667x | 15.500–16.000x |
| type=float w=31 h=17 layout=padded | ldc | below clock resolution | below clock resolution |
| type=float w=31 h=17 layout=negative-row | dmd | 10.333–10.667x | 15.500–16.000x |
| type=float w=31 h=17 layout=negative-row | ldc | below clock resolution | below clock resolution |
| type=float w=31 h=17 layout=repeated-row | dmd | 10.333–10.667x | 15.500–16.000x |
| type=float w=31 h=17 layout=repeated-row | ldc | below clock resolution | below clock resolution |
| type=float w=31 h=17 layout=overlap-row | dmd | 10.333–10.333x | 15.500–15.500x |
| type=float w=31 h=17 layout=overlap-row | ldc | below clock resolution | below clock resolution |
| type=float w=31 h=17 layout=overlap-negative | dmd | 10.333–11.000x | 15.500–16.500x |
| type=float w=31 h=17 layout=overlap-negative | ldc | below clock resolution | below clock resolution |
| type=float w=31 h=17 layout=universal | dmd | 1.000–1.032x | 1.000–1.032x |
| type=float w=31 h=17 layout=universal | ldc | 1.000–1.000x | 0.800–1.000x |
| type=float w=31 h=17 layout=universal-negative | dmd | 1.000–1.000x | 1.000–1.000x |
| type=float w=31 h=17 layout=universal-negative | ldc | 1.000–1.000x | 1.000–1.000x |
| type=float w=31 h=17 layout=zero-sample | dmd | 1.000–1.000x | 1.000–1.000x |
| type=float w=31 h=17 layout=zero-sample | ldc | 1.000–1.000x | 1.000–1.000x |
| type=float w=31 h=17 layout=zero-both | dmd | 1.000–1.000x | 1.000–1.000x |
| type=float w=31 h=17 layout=zero-both | ldc | 1.000–1.000x | 1.000–1.000x |
| type=float w=256 h=128 layout=contiguous | dmd | 10.811–11.536x | 20.684–22.446x |
| type=float w=256 h=128 layout=contiguous | ldc | 20.846–21.360x | 20.880–21.680x |
| type=float w=256 h=128 layout=padded | dmd | 10.844–11.238x | 21.098–21.435x |
| type=float w=256 h=128 layout=padded | ldc | 20.346–20.462x | 20.346–20.462x |
| type=float w=256 h=128 layout=negative-row | dmd | 10.860–11.928x | 20.903–22.490x |
| type=float w=256 h=128 layout=negative-row | ldc | 19.593–20.269x | 19.519–19.815x |
| type=float w=256 h=128 layout=repeated-row | dmd | 10.794–10.888x | 20.670–21.297x |
| type=float w=256 h=128 layout=repeated-row | ldc | 23.682–23.682x | 23.682–23.682x |
| type=float w=256 h=128 layout=overlap-row | dmd | 10.860–10.956x | 20.874–21.363x |
| type=float w=256 h=128 layout=overlap-row | ldc | 21.080–21.320x | 21.080–21.320x |
| type=float w=256 h=128 layout=overlap-negative | dmd | 10.735–10.876x | 20.453–21.275x |
| type=float w=256 h=128 layout=overlap-negative | ldc | 20.115–20.346x | 20.115–20.346x |
| type=float w=256 h=128 layout=universal | dmd | 0.980–1.004x | 1.001–1.003x |
| type=float w=256 h=128 layout=universal | ldc | 1.023–1.049x | 1.029–1.045x |
| type=float w=256 h=128 layout=universal-negative | dmd | 0.988–1.019x | 0.977–1.022x |
| type=float w=256 h=128 layout=universal-negative | ldc | 1.041–1.051x | 1.027–1.051x |
| type=float w=256 h=128 layout=zero-sample | dmd | 0.907–1.001x | 0.982–1.001x |
| type=float w=256 h=128 layout=zero-sample | ldc | 1.000–1.024x | 1.042–1.042x |
| type=float w=256 h=128 layout=zero-both | dmd | 0.991–1.188x | 1.003–1.188x |
| type=float w=256 h=128 layout=zero-both | ldc | 1.030–1.079x | 1.042–1.092x |
| type=float w=2048 h=512 layout=contiguous | dmd | 11.198–11.517x | 20.597–22.510x |
| type=float w=2048 h=512 layout=contiguous | ldc | 16.674–16.736x | 15.379–18.894x |
| type=float w=2048 h=512 layout=padded | dmd | 10.955–11.563x | 20.633–22.693x |
| type=float w=2048 h=512 layout=padded | ldc | 14.426–16.949x | 13.555–19.674x |
| type=float w=2048 h=512 layout=negative-row | dmd | 9.649–10.235x | 13.819–15.353x |
| type=float w=2048 h=512 layout=negative-row | ldc | 8.439–9.000x | 7.037–9.900x |
| type=float w=2048 h=512 layout=repeated-row | dmd | 11.164–11.391x | 22.186–24.339x |
| type=float w=2048 h=512 layout=repeated-row | ldc | 21.723–23.793x | 21.750–23.823x |
| type=float w=2048 h=512 layout=overlap-row | dmd | 10.973–11.444x | 21.425–21.607x |
| type=float w=2048 h=512 layout=overlap-row | ldc | 21.480–22.111x | 21.296–22.166x |
| type=float w=2048 h=512 layout=overlap-negative | dmd | 10.285–10.836x | 17.061–20.091x |
| type=float w=2048 h=512 layout=overlap-negative | ldc | 17.283–19.391x | 16.671–17.941x |
| type=float w=2048 h=512 layout=universal | dmd | 0.970–1.016x | 0.989–1.012x |
| type=float w=2048 h=512 layout=universal | ldc | 1.003–1.074x | 1.012–1.053x |
| type=float w=2048 h=512 layout=universal-negative | dmd | 1.005–1.016x | 0.976–1.013x |
| type=float w=2048 h=512 layout=universal-negative | ldc | 0.991–1.072x | 1.021–1.060x |
| type=float w=2048 h=512 layout=zero-sample | dmd | 0.992–1.043x | 0.988–1.040x |
| type=float w=2048 h=512 layout=zero-sample | ldc | 1.029–1.050x | 1.015–1.048x |
| type=float w=2048 h=512 layout=zero-both | dmd | 0.974–1.009x | 1.007–1.025x |
| type=float w=2048 h=512 layout=zero-both | ldc | 1.039–1.056x | 1.018–1.098x |
| type=ubyte w=31 h=17 layout=contiguous | dmd | 29.000–30.000x | 14.500–15.000x |
| type=ubyte w=31 h=17 layout=contiguous | ldc | below clock resolution | below clock resolution |
| type=ubyte w=31 h=17 layout=padded | dmd | 29.000–29.000x | 14.500–14.500x |
| type=ubyte w=31 h=17 layout=padded | ldc | below clock resolution | below clock resolution |
| type=ubyte w=31 h=17 layout=negative-row | dmd | 29.000–30.000x | 14.500–15.000x |
| type=ubyte w=31 h=17 layout=negative-row | ldc | below clock resolution | below clock resolution |
| type=ubyte w=31 h=17 layout=repeated-row | dmd | 29.000–30.000x | 14.500–15.000x |
| type=ubyte w=31 h=17 layout=repeated-row | ldc | below clock resolution | below clock resolution |
| type=ubyte w=31 h=17 layout=overlap-row | dmd | 29.000–30.000x | 14.500–15.000x |
| type=ubyte w=31 h=17 layout=overlap-row | ldc | below clock resolution | below clock resolution |
| type=ubyte w=31 h=17 layout=overlap-negative | dmd | 29.000–30.000x | 14.500–15.000x |
| type=ubyte w=31 h=17 layout=overlap-negative | ldc | below clock resolution | below clock resolution |
| type=ubyte w=31 h=17 layout=universal | dmd | 1.000–1.000x | 1.000–1.000x |
| type=ubyte w=31 h=17 layout=universal | ldc | 0.727–1.000x | 1.000–1.000x |
| type=ubyte w=31 h=17 layout=universal-negative | dmd | 1.000–1.034x | 1.000–1.034x |
| type=ubyte w=31 h=17 layout=universal-negative | ldc | 1.000–1.000x | 1.000–1.000x |
| type=ubyte w=31 h=17 layout=zero-sample | dmd | 1.000–1.034x | 1.000–1.034x |
| type=ubyte w=31 h=17 layout=zero-sample | ldc | 1.000–1.000x | 1.000–1.143x |
| type=ubyte w=31 h=17 layout=zero-both | dmd | 1.000–1.000x | 1.000–1.000x |
| type=ubyte w=31 h=17 layout=zero-both | ldc | 1.000–1.143x | 1.000–1.000x |
| type=ubyte w=256 h=128 layout=contiguous | dmd | 20.356–20.758x | 73.280–75.560x |
| type=ubyte w=256 h=128 layout=contiguous | ldc | 102.000–107.400x | 85.000–107.400x |
| type=ubyte w=256 h=128 layout=padded | dmd | 20.143–20.444x | 73.120–73.600x |
| type=ubyte w=256 h=128 layout=padded | ldc | 102.000–102.200x | 102.000–102.200x |
| type=ubyte w=256 h=128 layout=negative-row | dmd | 20.422–20.478x | 73.520–73.720x |
| type=ubyte w=256 h=128 layout=negative-row | ldc | 85.333–102.200x | 102.200–102.400x |
| type=ubyte w=256 h=128 layout=repeated-row | dmd | 20.411–20.444x | 68.037–68.148x |
| type=ubyte w=256 h=128 layout=repeated-row | ldc | 169.333–175.000x | 169.333–175.000x |
| type=ubyte w=256 h=128 layout=overlap-row | dmd | 20.422–23.033x | 73.520–83.840x |
| type=ubyte w=256 h=128 layout=overlap-row | ldc | 101.800–129.250x | 127.250–129.250x |
| type=ubyte w=256 h=128 layout=overlap-negative | dmd | 20.593–23.300x | 74.960–83.880x |
| type=ubyte w=256 h=128 layout=overlap-negative | ldc | 127.750–129.250x | 127.750–129.250x |
| type=ubyte w=256 h=128 layout=universal | dmd | 1.003–1.248x | 0.991–1.230x |
| type=ubyte w=256 h=128 layout=universal | ldc | 1.034–1.057x | 1.039–1.052x |
| type=ubyte w=256 h=128 layout=universal-negative | dmd | 1.003–1.069x | 0.999–1.065x |
| type=ubyte w=256 h=128 layout=universal-negative | ldc | 1.049–1.084x | 1.002–1.082x |
| type=ubyte w=256 h=128 layout=zero-sample | dmd | 0.996–1.003x | 0.979–1.046x |
| type=ubyte w=256 h=128 layout=zero-sample | ldc | 1.052–1.072x | 1.049–1.075x |
| type=ubyte w=256 h=128 layout=zero-both | dmd | 1.003–1.020x | 0.998–1.003x |
| type=ubyte w=256 h=128 layout=zero-both | ldc | 1.052–1.074x | 1.054–1.059x |
| type=ubyte w=2048 h=512 layout=contiguous | dmd | 21.278–22.359x | 229.078–291.288x |
| type=ubyte w=2048 h=512 layout=contiguous | ldc | 92.225–103.000x | 100.548–105.165x |
| type=ubyte w=2048 h=512 layout=padded | dmd | 20.594–22.251x | 230.462–285.197x |
| type=ubyte w=2048 h=512 layout=padded | ldc | 100.708–107.038x | 104.267–117.444x |
| type=ubyte w=2048 h=512 layout=negative-row | dmd | 18.949–20.479x | 91.838–132.358x |
| type=ubyte w=2048 h=512 layout=negative-row | ldc | 49.782–67.447x | 61.563–77.384x |
| type=ubyte w=2048 h=512 layout=repeated-row | dmd | 20.880–21.885x | 418.069–438.035x |
| type=ubyte w=2048 h=512 layout=repeated-row | ldc | 159.019–180.144x | 159.019–180.144x |
| type=ubyte w=2048 h=512 layout=overlap-row | dmd | 21.172–21.907x | 373.166–384.642x |
| type=ubyte w=2048 h=512 layout=overlap-row | ldc | 131.870–147.578x | 133.231–144.198x |
| type=ubyte w=2048 h=512 layout=overlap-negative | dmd | 20.186–21.889x | 188.183–209.416x |
| type=ubyte w=2048 h=512 layout=overlap-negative | ldc | 79.720–108.070x | 94.778–111.601x |
| type=ubyte w=2048 h=512 layout=universal | dmd | 0.986–1.027x | 0.997–1.031x |
| type=ubyte w=2048 h=512 layout=universal | ldc | 1.040–1.069x | 1.036–1.093x |
| type=ubyte w=2048 h=512 layout=universal-negative | dmd | 1.013–1.031x | 0.993–1.032x |
| type=ubyte w=2048 h=512 layout=universal-negative | ldc | 1.048–1.071x | 1.038–1.079x |
| type=ubyte w=2048 h=512 layout=zero-sample | dmd | 0.974–1.010x | 0.966–1.010x |
| type=ubyte w=2048 h=512 layout=zero-sample | ldc | 1.016–1.097x | 1.049–1.070x |
| type=ubyte w=2048 h=512 layout=zero-both | dmd | 0.986–1.002x | 0.961–0.993x |
| type=ubyte w=2048 h=512 layout=zero-both | ldc | 1.041–1.086x | 1.030–1.059x |
| type=Pod w=31 h=17 layout=contiguous | dmd | 11.333–31.000x | 5.667–10.333x |
| type=Pod w=31 h=17 layout=contiguous | ldc | 8.000–8.000x | below clock resolution |
| type=Pod w=31 h=17 layout=padded | dmd | 12.000–31.000x | 6.000–10.333x |
| type=Pod w=31 h=17 layout=padded | ldc | 8.000–8.000x | below clock resolution |
| type=Pod w=31 h=17 layout=negative-row | dmd | 16.000–31.000x | 10.333–10.667x |
| type=Pod w=31 h=17 layout=negative-row | ldc | 8.000–9.000x | below clock resolution |
| type=Pod w=31 h=17 layout=repeated-row | dmd | 31.000–31.000x | 10.333–10.333x |
| type=Pod w=31 h=17 layout=repeated-row | ldc | below clock resolution | 8.000–8.000x |
| type=Pod w=31 h=17 layout=overlap-row | dmd | 31.000–31.000x | 10.333–10.333x |
| type=Pod w=31 h=17 layout=overlap-row | ldc | 8.000–8.000x | below clock resolution |
| type=Pod w=31 h=17 layout=overlap-negative | dmd | 31.000–32.000x | 10.333–10.667x |
| type=Pod w=31 h=17 layout=overlap-negative | ldc | below clock resolution | below clock resolution |
| type=Pod w=31 h=17 layout=universal | dmd | 1.000–1.000x | 1.000–1.000x |
| type=Pod w=31 h=17 layout=universal | ldc | 1.000–1.000x | 1.000–1.000x |
| type=Pod w=31 h=17 layout=universal-negative | dmd | 1.000–1.032x | 0.969–1.032x |
| type=Pod w=31 h=17 layout=universal-negative | ldc | 0.800–1.000x | 1.000–1.000x |
| type=Pod w=31 h=17 layout=zero-sample | dmd | 1.000–1.000x | 1.000–1.000x |
| type=Pod w=31 h=17 layout=zero-sample | ldc | 1.000–1.000x | 1.000–1.000x |
| type=Pod w=31 h=17 layout=zero-both | dmd | 1.000–1.000x | 1.000–1.000x |
| type=Pod w=31 h=17 layout=zero-both | ldc | 1.000–1.000x | 1.000–1.000x |
