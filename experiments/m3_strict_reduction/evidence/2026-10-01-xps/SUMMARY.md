# Strict row-major reduction — xps evidence

Production baseline: `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`.

All six processes pass 42 timed cases, 56 semantic cases and invalid/empty/out-zero/cancellation contracts. All finite result bits and source fingerprints match. NaN semantics require class equality, not a platform-independent payload. Twelve rounds rotate four paths through every ordering position three times; each call is checked outside timing.

C++ is an already-validated descriptor execution reference with plane failure/empty semantics; it avoids Mir/layout classification and adds an external C ABI call. Both differences are explicit; it is not evidence of a complete independent raster library. No fast-math, contraction or LTO is enabled.

Large Canonical cases, contiguous/padded/negative/repeated rows, both corpora:

| Compiler | Public/Pointer | Public/Slice | Public/C++ reference | Max public/pointer/slice/C++ spread |
| --- | --- | --- | --- | --- |
| dmd | 0.992–1.151x | 0.879–1.050x | 1.010–1.170x | 11.76% / 12.64% / 12.75% / 10.61% |
| ldc | 0.982–1.022x | 0.978–1.020x | 0.981–1.024x | 7.94% / 7.17% / 7.30% / 7.18% |

Timings do not justify reassociation or fixed-lane substitution. Container results are diagnostic; production selection requires XPS qualification. AArch64 is unqualified. Tiny zero-duration samples are retained and zero-median ratios omitted.

| Case | Compiler | Public/Pointer | Public/Slice | Public/C++ |
| --- | --- | --- | --- | --- |
| w=31 h=17 layout=contiguous corpus=positive | dmd | 1.000–1.200x | 1.000–1.091x | 1.000–1.200x |
| w=31 h=17 layout=contiguous corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=contiguous corpus=cancellation | dmd | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=contiguous corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=padded corpus=positive | dmd | 1.200–1.200x | 1.000–1.091x | 1.200–1.200x |
| w=31 h=17 layout=padded corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=padded corpus=cancellation | dmd | 1.200–1.200x | 1.000–1.200x | 1.200–1.200x |
| w=31 h=17 layout=padded corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=negative-row corpus=positive | dmd | 1.200–1.200x | 1.000–1.200x | 1.200–1.200x |
| w=31 h=17 layout=negative-row corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=negative-row corpus=cancellation | dmd | 1.200–1.200x | 1.200–1.200x | 1.200–1.200x |
| w=31 h=17 layout=negative-row corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=universal corpus=positive | dmd | 1.000–1.000x | 1.000–1.000x | 1.200–1.200x |
| w=31 h=17 layout=universal corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=universal corpus=cancellation | dmd | 1.000–1.000x | 1.000–1.200x | 1.200–1.200x |
| w=31 h=17 layout=universal corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=universal-negative corpus=positive | dmd | 0.917–1.000x | 0.917–1.000x | 1.100–1.200x |
| w=31 h=17 layout=universal-negative corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=universal-negative corpus=cancellation | dmd | 0.917–1.000x | 0.917–1.000x | 1.100–1.200x |
| w=31 h=17 layout=universal-negative corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=repeated-row corpus=positive | dmd | 1.200–1.200x | 1.000–1.091x | 1.200–1.200x |
| w=31 h=17 layout=repeated-row corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=repeated-row corpus=cancellation | dmd | 1.200–1.200x | 1.000–1.200x | 1.200–1.200x |
| w=31 h=17 layout=repeated-row corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=zero-both corpus=positive | dmd | 1.000–1.200x | 1.000–1.200x | 1.200–1.200x |
| w=31 h=17 layout=zero-both corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=zero-both corpus=cancellation | dmd | 1.000–1.000x | 1.000–1.000x | 1.200–1.200x |
| w=31 h=17 layout=zero-both corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=contiguous corpus=positive | dmd | 0.990–0.995x | 0.881–0.938x | 1.010–1.014x |
| w=256 h=128 layout=contiguous corpus=positive | ldc | 1.000–1.003x | 1.000–1.003x | 1.000–1.003x |
| w=256 h=128 layout=contiguous corpus=cancellation | dmd | 0.992–1.000x | 0.881–0.886x | 1.013–1.019x |
| w=256 h=128 layout=contiguous corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.003x | 1.000–1.003x |
| w=256 h=128 layout=padded corpus=positive | dmd | 1.123–1.129x | 0.997–0.999x | 1.149–1.150x |
| w=256 h=128 layout=padded corpus=positive | ldc | 1.000–1.003x | 1.000–1.003x | 1.000–1.003x |
| w=256 h=128 layout=padded corpus=cancellation | dmd | 1.123–1.129x | 0.997–0.999x | 1.147–1.151x |
| w=256 h=128 layout=padded corpus=cancellation | ldc | 1.000–1.003x | 1.000–1.003x | 1.000–1.003x |
| w=256 h=128 layout=negative-row corpus=positive | dmd | 1.126–1.129x | 1.149–1.150x | 1.149–1.151x |
| w=256 h=128 layout=negative-row corpus=positive | ldc | 1.000–1.003x | 1.000–1.003x | 1.000–1.003x |
| w=256 h=128 layout=negative-row corpus=cancellation | dmd | 1.126–1.129x | 1.024–1.150x | 1.150–1.151x |
| w=256 h=128 layout=negative-row corpus=cancellation | ldc | 1.000–1.003x | 1.000–1.003x | 1.000–1.003x |
| w=256 h=128 layout=universal corpus=positive | dmd | 1.000–1.002x | 1.000–1.002x | 1.085–1.095x |
| w=256 h=128 layout=universal corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=universal corpus=cancellation | dmd | 1.000–1.000x | 1.000–1.000x | 1.083–1.094x |
| w=256 h=128 layout=universal corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=universal-negative corpus=positive | dmd | 0.998–1.000x | 0.997–1.000x | 1.083–1.094x |
| w=256 h=128 layout=universal-negative corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=universal-negative corpus=cancellation | dmd | 1.000–1.002x | 0.998–1.000x | 1.083–1.094x |
| w=256 h=128 layout=universal-negative corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=repeated-row corpus=positive | dmd | 1.128–1.150x | 1.147–1.150x | 1.150–1.151x |
| w=256 h=128 layout=repeated-row corpus=positive | ldc | 1.000–1.003x | 1.000–1.003x | 1.000–1.003x |
| w=256 h=128 layout=repeated-row corpus=cancellation | dmd | 1.128–1.150x | 1.147–1.150x | 1.150–1.151x |
| w=256 h=128 layout=repeated-row corpus=cancellation | ldc | 0.997–1.003x | 1.003–1.003x | 1.003–1.003x |
| w=256 h=128 layout=zero-both corpus=positive | dmd | 1.000–1.000x | 1.000–1.000x | 1.080–1.085x |
| w=256 h=128 layout=zero-both corpus=positive | ldc | 1.003–1.003x | 1.003–1.003x | 1.003–1.003x |
| w=256 h=128 layout=zero-both corpus=cancellation | dmd | 1.000–1.000x | 1.000–1.003x | 1.084–1.085x |
| w=256 h=128 layout=zero-both corpus=cancellation | ldc | 1.003–1.003x | 0.998–1.003x | 1.000–1.003x |
| w=2048 h=512 layout=contiguous corpus=positive | dmd | 0.992–1.007x | 0.883–0.913x | 1.010–1.014x |
| w=2048 h=512 layout=contiguous corpus=positive | ldc | 1.000–1.002x | 0.996–1.000x | 1.000–1.013x |
| w=2048 h=512 layout=contiguous corpus=cancellation | dmd | 1.006–1.006x | 0.879–0.895x | 1.010–1.010x |
| w=2048 h=512 layout=contiguous corpus=cancellation | ldc | 1.000–1.000x | 0.999–1.000x | 1.000–1.000x |
| w=2048 h=512 layout=padded corpus=positive | dmd | 1.097–1.132x | 0.977–1.000x | 1.135–1.137x |
| w=2048 h=512 layout=padded corpus=positive | ldc | 0.984–1.000x | 0.989–1.000x | 0.989–1.000x |
| w=2048 h=512 layout=padded corpus=cancellation | dmd | 1.116–1.147x | 0.995–1.020x | 1.148–1.164x |
| w=2048 h=512 layout=padded corpus=cancellation | ldc | 1.000–1.022x | 0.978–1.000x | 0.981–1.000x |
| w=2048 h=512 layout=negative-row corpus=positive | dmd | 1.130–1.151x | 0.991–1.025x | 1.136–1.170x |
| w=2048 h=512 layout=negative-row corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=2048 h=512 layout=negative-row corpus=cancellation | dmd | 1.129–1.142x | 0.988–0.993x | 1.123–1.135x |
| w=2048 h=512 layout=negative-row corpus=cancellation | ldc | 0.982–1.000x | 0.992–1.020x | 1.000–1.013x |
| w=2048 h=512 layout=universal corpus=positive | dmd | 0.992–1.005x | 0.986–1.013x | 1.039–1.075x |
| w=2048 h=512 layout=universal corpus=positive | ldc | 0.965–1.029x | 0.991–1.007x | 0.990–1.025x |
| w=2048 h=512 layout=universal corpus=cancellation | dmd | 0.985–0.997x | 0.981–0.993x | 1.064–1.070x |
| w=2048 h=512 layout=universal corpus=cancellation | ldc | 0.993–1.010x | 0.995–1.024x | 0.993–1.008x |
| w=2048 h=512 layout=universal-negative corpus=positive | dmd | 0.992–1.012x | 1.005–1.028x | 1.057–1.107x |
| w=2048 h=512 layout=universal-negative corpus=positive | ldc | 0.993–1.010x | 0.997–1.008x | 0.999–1.006x |
| w=2048 h=512 layout=universal-negative corpus=cancellation | dmd | 0.992–1.021x | 1.000–1.024x | 1.076–1.095x |
| w=2048 h=512 layout=universal-negative corpus=cancellation | ldc | 1.001–1.012x | 0.998–1.008x | 0.999–1.016x |
| w=2048 h=512 layout=repeated-row corpus=positive | dmd | 1.122–1.130x | 1.019–1.048x | 1.070–1.134x |
| w=2048 h=512 layout=repeated-row corpus=positive | ldc | 1.000–1.014x | 1.000–1.019x | 1.000–1.024x |
| w=2048 h=512 layout=repeated-row corpus=cancellation | dmd | 1.130–1.130x | 1.014–1.050x | 1.134–1.134x |
| w=2048 h=512 layout=repeated-row corpus=cancellation | ldc | 1.000–1.000x | 0.995–1.000x | 1.000–1.000x |
| w=2048 h=512 layout=zero-both corpus=positive | dmd | 0.999–1.015x | 0.999–1.018x | 1.068–1.086x |
| w=2048 h=512 layout=zero-both corpus=positive | ldc | 1.000–1.035x | 1.000–1.035x | 0.997–1.035x |
| w=2048 h=512 layout=zero-both corpus=cancellation | dmd | 0.999–1.000x | 0.999–1.000x | 1.067–1.068x |
| w=2048 h=512 layout=zero-both corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
