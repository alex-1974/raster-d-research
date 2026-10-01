# Strict row-major reduction — container evidence

Production baseline: `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`.

All six processes pass 42 timed cases, 56 semantic cases and invalid/empty/out-zero/cancellation contracts. All finite result bits and source fingerprints match. NaN semantics require class equality, not a platform-independent payload. Twelve rounds rotate four paths through every ordering position three times; each call is checked outside timing.

C++ is an already-validated descriptor execution reference with plane failure/empty semantics; it avoids Mir/layout classification and adds an external C ABI call. Both differences are explicit; it is not evidence of a complete independent raster library. No fast-math, contraction or LTO is enabled.

Large Canonical cases, contiguous/padded/negative/repeated rows, both corpora:

| Compiler | Public/Pointer | Public/Slice | Public/C++ reference | Max public/pointer/slice/C++ spread |
| --- | --- | --- | --- | --- |
| dmd | 0.854–1.137x | 0.795–1.159x | 0.986–1.254x | 26.49% / 38.21% / 20.70% / 17.65% |
| ldc | 0.809–1.141x | 0.898–1.093x | 0.899–1.130x | 18.70% / 24.22% / 18.22% / 12.46% |

Timings do not justify reassociation or fixed-lane substitution. Container results are diagnostic; production selection requires XPS qualification. AArch64 is unqualified. Tiny zero-duration samples are retained and zero-median ratios omitted.

| Case | Compiler | Public/Pointer | Public/Slice | Public/C++ |
| --- | --- | --- | --- | --- |
| w=31 h=17 layout=contiguous corpus=positive | dmd | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=contiguous corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=contiguous corpus=cancellation | dmd | 1.000–1.125x | 1.000–1.125x | 1.000–1.125x |
| w=31 h=17 layout=contiguous corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=padded corpus=positive | dmd | 1.250–1.250x | 1.250–1.250x | 1.250–1.250x |
| w=31 h=17 layout=padded corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=padded corpus=cancellation | dmd | 1.250–1.250x | 1.250–1.250x | 1.250–1.250x |
| w=31 h=17 layout=padded corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=negative-row corpus=positive | dmd | 1.250–1.250x | 1.250–1.250x | 1.250–1.250x |
| w=31 h=17 layout=negative-row corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=negative-row corpus=cancellation | dmd | 1.250–1.250x | 1.250–1.250x | 1.250–1.250x |
| w=31 h=17 layout=negative-row corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=universal corpus=positive | dmd | 1.000–1.000x | 1.000–1.000x | 1.250–1.250x |
| w=31 h=17 layout=universal corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=universal corpus=cancellation | dmd | 1.000–1.000x | 1.000–1.000x | 1.250–1.250x |
| w=31 h=17 layout=universal corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=universal-negative corpus=positive | dmd | 1.000–1.000x | 1.000–1.000x | 1.250–1.250x |
| w=31 h=17 layout=universal-negative corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=universal-negative corpus=cancellation | dmd | 0.900–1.000x | 0.900–1.000x | 1.125–1.250x |
| w=31 h=17 layout=universal-negative corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=repeated-row corpus=positive | dmd | 1.250–1.250x | 1.250–1.250x | 1.250–1.250x |
| w=31 h=17 layout=repeated-row corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=repeated-row corpus=cancellation | dmd | 1.250–1.250x | 1.250–1.250x | 1.250–1.250x |
| w=31 h=17 layout=repeated-row corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=zero-both corpus=positive | dmd | 0.900–1.000x | 0.900–1.000x | 1.125–1.250x |
| w=31 h=17 layout=zero-both corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=31 h=17 layout=zero-both corpus=cancellation | dmd | 1.000–1.000x | 1.000–1.000x | 1.250–1.250x |
| w=31 h=17 layout=zero-both corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=contiguous corpus=positive | dmd | 0.996–1.929x | 1.000–1.929x | 1.002–1.936x |
| w=256 h=128 layout=contiguous corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=contiguous corpus=cancellation | dmd | 0.998–1.004x | 1.000–1.004x | 1.004–1.004x |
| w=256 h=128 layout=contiguous corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=padded corpus=positive | dmd | 1.000–1.000x | 0.996–1.004x | 1.000–1.006x |
| w=256 h=128 layout=padded corpus=positive | ldc | 1.000–1.002x | 1.000–1.002x | 1.000–1.002x |
| w=256 h=128 layout=padded corpus=cancellation | dmd | 1.000–1.006x | 1.002–1.008x | 1.002–1.009x |
| w=256 h=128 layout=padded corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=negative-row corpus=positive | dmd | 1.000–1.004x | 1.000–1.004x | 1.004–1.008x |
| w=256 h=128 layout=negative-row corpus=positive | ldc | 1.000–1.002x | 1.000–1.002x | 1.000–1.002x |
| w=256 h=128 layout=negative-row corpus=cancellation | dmd | 0.996–1.004x | 1.000–1.004x | 1.000–1.006x |
| w=256 h=128 layout=negative-row corpus=cancellation | ldc | 1.000–1.002x | 1.000–1.002x | 1.000–1.002x |
| w=256 h=128 layout=universal corpus=positive | dmd | 1.000–1.000x | 1.000–1.002x | 1.004–1.006x |
| w=256 h=128 layout=universal corpus=positive | ldc | 1.000–1.004x | 1.000–1.004x | 1.000–1.004x |
| w=256 h=128 layout=universal corpus=cancellation | dmd | 0.996–1.000x | 0.998–1.000x | 1.002–1.006x |
| w=256 h=128 layout=universal corpus=cancellation | ldc | 1.000–1.004x | 0.998–1.004x | 1.000–1.004x |
| w=256 h=128 layout=universal-negative corpus=positive | dmd | 0.998–1.002x | 0.998–1.004x | 1.002–1.008x |
| w=256 h=128 layout=universal-negative corpus=positive | ldc | 1.000–1.053x | 1.000–1.053x | 1.000–1.053x |
| w=256 h=128 layout=universal-negative corpus=cancellation | dmd | 1.000–1.002x | 1.000–1.002x | 1.004–1.006x |
| w=256 h=128 layout=universal-negative corpus=cancellation | ldc | 1.000–1.004x | 1.000–1.004x | 1.000–1.004x |
| w=256 h=128 layout=repeated-row corpus=positive | dmd | 1.000–1.004x | 1.000–1.004x | 1.000–1.004x |
| w=256 h=128 layout=repeated-row corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=repeated-row corpus=cancellation | dmd | 1.000–1.004x | 1.000–1.004x | 1.000–1.004x |
| w=256 h=128 layout=repeated-row corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=zero-both corpus=positive | dmd | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=zero-both corpus=positive | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=256 h=128 layout=zero-both corpus=cancellation | dmd | 0.996–1.000x | 0.998–1.000x | 1.000–1.000x |
| w=256 h=128 layout=zero-both corpus=cancellation | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x |
| w=2048 h=512 layout=contiguous corpus=positive | dmd | 0.907–1.051x | 0.842–0.972x | 1.025–1.172x |
| w=2048 h=512 layout=contiguous corpus=positive | ldc | 0.978–1.013x | 0.948–1.021x | 0.935–0.990x |
| w=2048 h=512 layout=contiguous corpus=cancellation | dmd | 0.854–0.993x | 0.874–0.985x | 1.010–1.118x |
| w=2048 h=512 layout=contiguous corpus=cancellation | ldc | 0.809–1.141x | 0.898–1.089x | 0.899–1.075x |
| w=2048 h=512 layout=padded corpus=positive | dmd | 0.960–1.006x | 0.999–1.159x | 1.170–1.198x |
| w=2048 h=512 layout=padded corpus=positive | ldc | 0.903–1.044x | 0.982–1.065x | 0.940–0.987x |
| w=2048 h=512 layout=padded corpus=cancellation | dmd | 0.906–1.137x | 0.897–0.976x | 1.007–1.205x |
| w=2048 h=512 layout=padded corpus=cancellation | ldc | 0.975–1.094x | 1.011–1.092x | 1.010–1.080x |
| w=2048 h=512 layout=negative-row corpus=positive | dmd | 0.936–0.995x | 0.844–1.070x | 0.991–1.190x |
| w=2048 h=512 layout=negative-row corpus=positive | ldc | 0.999–1.097x | 0.916–1.092x | 0.937–1.130x |
| w=2048 h=512 layout=negative-row corpus=cancellation | dmd | 0.935–1.135x | 0.938–1.064x | 1.030–1.254x |
| w=2048 h=512 layout=negative-row corpus=cancellation | ldc | 0.963–1.061x | 0.987–1.014x | 0.958–1.017x |
| w=2048 h=512 layout=universal corpus=positive | dmd | 0.921–1.120x | 0.916–1.099x | 1.027–1.159x |
| w=2048 h=512 layout=universal corpus=positive | ldc | 1.024–1.032x | 1.015–1.119x | 1.011–1.167x |
| w=2048 h=512 layout=universal corpus=cancellation | dmd | 0.930–0.982x | 1.047–1.162x | 1.123–1.253x |
| w=2048 h=512 layout=universal corpus=cancellation | ldc | 0.964–1.107x | 1.013–1.160x | 0.971–1.092x |
| w=2048 h=512 layout=universal-negative corpus=positive | dmd | 0.975–1.083x | 0.914–1.104x | 0.951–1.240x |
| w=2048 h=512 layout=universal-negative corpus=positive | ldc | 0.956–1.054x | 0.968–1.038x | 0.972–1.053x |
| w=2048 h=512 layout=universal-negative corpus=cancellation | dmd | 1.063–1.084x | 0.992–1.022x | 1.036–1.065x |
| w=2048 h=512 layout=universal-negative corpus=cancellation | ldc | 0.988–1.012x | 0.878–1.012x | 0.959–1.026x |
| w=2048 h=512 layout=repeated-row corpus=positive | dmd | 0.919–1.010x | 0.795–1.128x | 0.986–1.210x |
| w=2048 h=512 layout=repeated-row corpus=positive | ldc | 0.997–1.021x | 0.931–0.974x | 0.961–1.018x |
| w=2048 h=512 layout=repeated-row corpus=cancellation | dmd | 0.958–1.116x | 0.925–1.074x | 1.009–1.237x |
| w=2048 h=512 layout=repeated-row corpus=cancellation | ldc | 0.978–1.141x | 0.954–1.093x | 0.931–1.108x |
| w=2048 h=512 layout=zero-both corpus=positive | dmd | 1.004–1.095x | 0.866–1.182x | 1.019–1.235x |
| w=2048 h=512 layout=zero-both corpus=positive | ldc | 0.889–1.000x | 0.891–0.963x | 0.912–0.982x |
| w=2048 h=512 layout=zero-both corpus=cancellation | dmd | 1.005–1.101x | 0.978–1.000x | 0.999–1.231x |
| w=2048 h=512 layout=zero-both corpus=cancellation | ldc | 0.891–1.018x | 0.921–1.164x | 0.955–1.163x |
