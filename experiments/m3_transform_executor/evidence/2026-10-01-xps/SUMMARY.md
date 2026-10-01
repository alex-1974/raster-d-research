# Post-bounds transform executor — container evidence

Baseline: `b263477bdbbe0dc3e8c469ac3867eda345ba364c`.

All six independent processes pass 41 cases and special-float bit checks; all hashes match across processes and compilers. Each case has two warmups and nine timed calls per path, with cyclic order and full source/output/padding checks outside timing.

Large (2048x512) baseline/candidate median ratios across three processes, including contiguous and all four padded row-sign combinations:

| Type | Compiler | Pointer speedup range | Slice speedup range | Max public / pointer / slice median spread |
| --- | --- | --- | --- | --- |
| float | dmd | 17.433–24.001x | 9.233–10.360x | 8.82% / 46.56% / 12.39% |
| float | ldc | 8.209–12.974x | 8.232–13.181x | 9.44% / 39.66% / 36.19% |
| ubyte | dmd | 9.015–9.475x | 7.390–7.585x | 2.92% / 5.44% / 2.38% |
| ubyte | ldc | 5.751–37.896x | 5.507–37.708x | 7.98% / 10.58% / 20.47% |

Container/VM timing is diagnostic evidence, not XPS or AArch64 qualification. Small workloads and Universal fallback have no tight timing threshold. Pointer versus slice selection and production admission require a separate review of stable reference-machine evidence.

## Per-case paired ratios

| Case | Compiler | Pointer range | Slice range |
| --- | --- | --- | --- |
| type=float w=31 h=17 sn=false dn=false padding=32 step=1 nx=false | dmd | 12.800–16.000x | 7.875–8.000x |
| type=float w=31 h=17 sn=false dn=false padding=32 step=1 nx=false | ldc | 9.000–9.000x | 9.000–9.000x |
| type=float w=31 h=17 sn=false dn=true padding=32 step=1 nx=false | dmd | 12.800–15.750x | 7.875–8.000x |
| type=float w=31 h=17 sn=false dn=true padding=32 step=1 nx=false | ldc | 9.000–9.500x | 6.000–9.000x |
| type=float w=31 h=17 sn=true dn=false padding=32 step=1 nx=false | dmd | 12.600–12.800x | 7.875–8.000x |
| type=float w=31 h=17 sn=true dn=false padding=32 step=1 nx=false | ldc | 9.000–9.000x | 9.000–9.000x |
| type=float w=31 h=17 sn=true dn=true padding=32 step=1 nx=false | dmd | 12.800–15.750x | 7.875–8.000x |
| type=float w=31 h=17 sn=true dn=true padding=32 step=1 nx=false | ldc | 9.000–9.500x | 6.333–9.000x |
| type=float w=31 h=17 sn=false dn=false padding=0 step=1 nx=false | dmd | 15.750–16.000x | 7.875–8.000x |
| type=float w=31 h=17 sn=false dn=false padding=0 step=1 nx=false | ldc | 8.500–9.000x | 8.500–9.000x |
| type=float w=256 h=128 sn=false dn=false padding=32 step=1 nx=false | dmd | 23.354–25.156x | 9.746–10.509x |
| type=float w=256 h=128 sn=false dn=false padding=32 step=1 nx=false | ldc | 25.951–26.488x | 24.222–25.951x |
| type=float w=256 h=128 sn=false dn=true padding=32 step=1 nx=false | dmd | 23.348–26.739x | 9.740–11.226x |
| type=float w=256 h=128 sn=false dn=true padding=32 step=1 nx=false | ldc | 9.752–9.936x | 8.933–9.075x |
| type=float w=256 h=128 sn=true dn=false padding=32 step=1 nx=false | dmd | 23.253–25.449x | 9.768–10.814x |
| type=float w=256 h=128 sn=true dn=false padding=32 step=1 nx=false | ldc | 9.628–9.714x | 8.769–8.918x |
| type=float w=256 h=128 sn=true dn=true padding=32 step=1 nx=false | dmd | 23.060–25.259x | 9.765–10.669x |
| type=float w=256 h=128 sn=true dn=true padding=32 step=1 nx=false | ldc | 9.688–9.925x | 8.967–9.077x |
| type=float w=256 h=128 sn=false dn=false padding=0 step=1 nx=false | dmd | 23.479–24.500x | 9.763–10.224x |
| type=float w=256 h=128 sn=false dn=false padding=0 step=1 nx=false | ldc | 27.282–27.872x | 26.512–28.000x |
| type=float w=2048 h=512 sn=false dn=false padding=32 step=1 nx=false | dmd | 21.033–23.161x | 9.233–9.780x |
| type=float w=2048 h=512 sn=false dn=false padding=32 step=1 nx=false | ldc | 10.645–12.974x | 9.717–12.974x |
| type=float w=2048 h=512 sn=false dn=true padding=32 step=1 nx=false | dmd | 21.924–23.372x | 9.760–10.078x |
| type=float w=2048 h=512 sn=false dn=true padding=32 step=1 nx=false | ldc | 8.209–8.494x | 8.232–8.576x |
| type=float w=2048 h=512 sn=true dn=false padding=32 step=1 nx=false | dmd | 17.433–23.480x | 9.789–10.204x |
| type=float w=2048 h=512 sn=true dn=false padding=32 step=1 nx=false | ldc | 8.792–9.003x | 8.676–9.074x |
| type=float w=2048 h=512 sn=true dn=true padding=32 step=1 nx=false | dmd | 22.166–23.578x | 9.688–9.919x |
| type=float w=2048 h=512 sn=true dn=true padding=32 step=1 nx=false | ldc | 8.683–8.788x | 8.766–8.917x |
| type=float w=2048 h=512 sn=false dn=false padding=0 step=1 nx=false | dmd | 22.617–24.001x | 9.722–10.360x |
| type=float w=2048 h=512 sn=false dn=false padding=0 step=1 nx=false | ldc | 9.927–12.910x | 10.714–13.181x |
| type=ubyte w=31 h=17 sn=false dn=false padding=32 step=1 nx=false | dmd | 7.556–8.000x | 6.273–6.800x |
| type=ubyte w=31 h=17 sn=false dn=false padding=32 step=1 nx=false | ldc | 10.500–11.500x | 10.500–11.500x |
| type=ubyte w=31 h=17 sn=false dn=true padding=32 step=1 nx=false | dmd | 7.444–8.125x | 6.182–6.700x |
| type=ubyte w=31 h=17 sn=false dn=true padding=32 step=1 nx=false | ldc | 3.571–5.250x | 3.571–5.250x |
| type=ubyte w=31 h=17 sn=true dn=false padding=32 step=1 nx=false | dmd | 7.444–8.000x | 6.273–6.700x |
| type=ubyte w=31 h=17 sn=true dn=false padding=32 step=1 nx=false | ldc | 4.667–5.250x | 4.667–5.250x |
| type=ubyte w=31 h=17 sn=true dn=true padding=32 step=1 nx=false | dmd | 7.444–8.000x | 6.182–6.700x |
| type=ubyte w=31 h=17 sn=true dn=true padding=32 step=1 nx=false | ldc | 4.000–5.250x | 4.000–5.250x |
| type=ubyte w=31 h=17 sn=false dn=false padding=0 step=1 nx=false | dmd | 7.444–8.000x | 6.364–6.700x |
| type=ubyte w=31 h=17 sn=false dn=false padding=0 step=1 nx=false | ldc | 9.250–10.500x | 9.250–10.500x |
| type=ubyte w=256 h=128 sn=false dn=false padding=32 step=1 nx=false | dmd | 9.179–9.474x | 7.340–7.535x |
| type=ubyte w=256 h=128 sn=false dn=false padding=32 step=1 nx=false | ldc | 36.029–36.485x | 36.029–36.485x |
| type=ubyte w=256 h=128 sn=false dn=true padding=32 step=1 nx=false | dmd | 9.128–9.971x | 7.285–7.950x |
| type=ubyte w=256 h=128 sn=false dn=true padding=32 step=1 nx=false | ldc | 5.559–5.588x | 5.564–5.584x |
| type=ubyte w=256 h=128 sn=true dn=false padding=32 step=1 nx=false | dmd | 9.119–9.969x | 7.299–8.002x |
| type=ubyte w=256 h=128 sn=true dn=false padding=32 step=1 nx=false | ldc | 5.545–5.558x | 5.545–5.558x |
| type=ubyte w=256 h=128 sn=true dn=true padding=32 step=1 nx=false | dmd | 9.107–9.182x | 7.286–7.352x |
| type=ubyte w=256 h=128 sn=true dn=true padding=32 step=1 nx=false | ldc | 5.548–5.570x | 5.539–5.647x |
| type=ubyte w=256 h=128 sn=false dn=false padding=0 step=1 nx=false | dmd | 9.138–9.633x | 7.283–7.695x |
| type=ubyte w=256 h=128 sn=false dn=false padding=0 step=1 nx=false | ldc | 35.412–36.294x | 36.029–36.485x |
| type=ubyte w=2048 h=512 sn=false dn=false padding=32 step=1 nx=false | dmd | 9.087–9.375x | 7.431–7.495x |
| type=ubyte w=2048 h=512 sn=false dn=false padding=32 step=1 nx=false | ldc | 35.130–36.093x | 32.037–35.741x |
| type=ubyte w=2048 h=512 sn=false dn=true padding=32 step=1 nx=false | dmd | 9.015–9.475x | 7.439–7.544x |
| type=ubyte w=2048 h=512 sn=false dn=true padding=32 step=1 nx=false | ldc | 5.751–5.829x | 5.720–5.774x |
| type=ubyte w=2048 h=512 sn=true dn=false padding=32 step=1 nx=false | dmd | 9.271–9.363x | 7.449–7.585x |
| type=ubyte w=2048 h=512 sn=true dn=false padding=32 step=1 nx=false | ldc | 5.760–5.827x | 5.707–5.756x |
| type=ubyte w=2048 h=512 sn=true dn=true padding=32 step=1 nx=false | dmd | 9.326–9.402x | 7.472–7.527x |
| type=ubyte w=2048 h=512 sn=true dn=true padding=32 step=1 nx=false | ldc | 5.786–6.084x | 5.507–5.803x |
| type=ubyte w=2048 h=512 sn=false dn=false padding=0 step=1 nx=false | dmd | 9.243–9.475x | 7.390–7.447x |
| type=ubyte w=2048 h=512 sn=false dn=false padding=0 step=1 nx=false | ldc | 36.318–37.896x | 35.516–37.708x |
| type=float w=31 h=17 sn=false dn=true padding=32 step=2 nx=false | dmd | 0.970–0.984x | 1.000–1.000x |
| type=float w=31 h=17 sn=false dn=true padding=32 step=2 nx=false | ldc | 1.059–1.267x | 0.950–1.000x |
| type=float w=31 h=17 sn=true dn=false padding=32 step=2 nx=true | dmd | 0.984–0.985x | 1.000–1.000x |
| type=float w=31 h=17 sn=true dn=false padding=32 step=2 nx=true | ldc | 1.200–1.267x | 1.000–1.056x |
| type=ubyte w=31 h=17 sn=false dn=true padding=32 step=2 nx=false | dmd | 0.957–0.971x | 0.930–0.932x |
| type=ubyte w=31 h=17 sn=false dn=true padding=32 step=2 nx=false | ldc | 1.000–1.050x | 1.000–1.050x |
| type=ubyte w=31 h=17 sn=true dn=false padding=32 step=2 nx=true | dmd | 0.957–0.971x | 0.918–0.930x |
| type=ubyte w=31 h=17 sn=true dn=false padding=32 step=2 nx=true | ldc | 1.000–1.000x | 1.000–1.000x |
| type=Pod w=31 h=17 sn=false dn=true padding=32 step=2 nx=false | dmd | 0.985–1.031x | 1.015–1.031x |
| type=Pod w=31 h=17 sn=false dn=true padding=32 step=2 nx=false | ldc | 1.000–1.038x | 1.000–1.000x |
| type=Pod w=31 h=17 sn=true dn=false padding=32 step=2 nx=true | dmd | 1.000–1.000x | 1.015–1.031x |
| type=Pod w=31 h=17 sn=true dn=false padding=32 step=2 nx=true | ldc | 1.000–1.000x | 1.000–1.000x |
| type=Pod w=31 h=17 sn=false dn=false padding=32 step=1 nx=false | dmd | 2.481–2.519x | 2.481–2.519x |
| type=Pod w=31 h=17 sn=false dn=false padding=32 step=1 nx=false | ldc | 6.500–6.750x | 6.500–6.750x |
| type=Pod w=31 h=17 sn=false dn=true padding=32 step=1 nx=false | dmd | 2.429–2.481x | 2.429–2.481x |
| type=Pod w=31 h=17 sn=false dn=true padding=32 step=1 nx=false | ldc | 2.500–3.375x | 2.500–3.000x |
| type=Pod w=31 h=17 sn=true dn=false padding=32 step=1 nx=false | dmd | 2.429–2.481x | 2.429–2.481x |
| type=Pod w=31 h=17 sn=true dn=false padding=32 step=1 nx=false | ldc | 3.250–3.375x | 2.889–3.000x |
| type=Pod w=31 h=17 sn=true dn=true padding=32 step=1 nx=false | dmd | 2.429–2.481x | 2.444–2.519x |
| type=Pod w=31 h=17 sn=true dn=true padding=32 step=1 nx=false | ldc | 3.250–3.375x | 2.889–3.000x |
| type=Pod w=31 h=17 sn=false dn=false padding=0 step=1 nx=false | dmd | 2.538–2.615x | 2.538–2.615x |
| type=Pod w=31 h=17 sn=false dn=false padding=0 step=1 nx=false | ldc | 6.500–6.750x | 6.500–6.750x |
