# Post-bounds transform executor — container evidence

Baseline: `b263477bdbbe0dc3e8c469ac3867eda345ba364c`.

All six independent processes pass 41 cases and special-float bit checks; all hashes match across processes and compilers. Each case has two warmups and nine timed calls per path, with cyclic order and full source/output/padding checks outside timing.

Large (2048x512) baseline/candidate median ratios across three processes, including contiguous and all four padded row-sign combinations:

| Type | Compiler | Pointer speedup range | Slice speedup range | Max public / pointer / slice median spread |
| --- | --- | --- | --- | --- |
| float | dmd | 12.673–16.656x | 12.855–16.090x | 8.37% / 17.97% / 10.26% |
| float | ldc | 5.790–21.652x | 6.406–22.470x | 3.66% / 18.45% / 23.38% |
| ubyte | dmd | 7.320–8.405x | 6.420–7.258x | 13.58% / 13.00% / 13.06% |
| ubyte | ldc | 3.703–41.417x | 3.687–35.168x | 7.17% / 29.78% / 10.93% |

Container/VM timing is diagnostic evidence, not XPS or AArch64 qualification. Small workloads and Universal fallback have no tight timing threshold. Pointer versus slice selection and production admission require a separate review of stable reference-machine evidence.

## Per-case paired ratios

| Case | Compiler | Pointer range | Slice range |
| --- | --- | --- | --- |
| type=float w=31 h=17 sn=false dn=false padding=32 step=1 nx=false | dmd | 11.250–11.500x | 11.250–11.500x |
| type=float w=31 h=17 sn=false dn=false padding=32 step=1 nx=false | ldc | 16.000–16.000x | 16.000–16.000x |
| type=float w=31 h=17 sn=false dn=true padding=32 step=1 nx=false | dmd | 11.250–11.250x | 11.250–11.250x |
| type=float w=31 h=17 sn=false dn=true padding=32 step=1 nx=false | ldc | 8.000–8.000x | 8.000–8.000x |
| type=float w=31 h=17 sn=true dn=false padding=32 step=1 nx=false | dmd | 11.250–11.750x | 11.250–11.750x |
| type=float w=31 h=17 sn=true dn=false padding=32 step=1 nx=false | ldc | 8.000–8.000x | 8.000–8.000x |
| type=float w=31 h=17 sn=true dn=true padding=32 step=1 nx=false | dmd | 11.250–11.750x | 11.250–11.750x |
| type=float w=31 h=17 sn=true dn=true padding=32 step=1 nx=false | ldc | 8.000–8.000x | 8.000–8.000x |
| type=float w=31 h=17 sn=false dn=false padding=0 step=1 nx=false | dmd | 11.250–11.500x | 11.250–11.500x |
| type=float w=31 h=17 sn=false dn=false padding=0 step=1 nx=false | ldc | 16.000–17.000x | 16.000–17.000x |
| type=float w=256 h=128 sn=false dn=false padding=32 step=1 nx=false | dmd | 15.223–16.564x | 15.390–16.473x |
| type=float w=256 h=128 sn=false dn=false padding=32 step=1 nx=false | ldc | 31.562–34.793x | 30.576–37.222x |
| type=float w=256 h=128 sn=false dn=true padding=32 step=1 nx=false | dmd | 15.142–16.625x | 15.309–16.808x |
| type=float w=256 h=128 sn=false dn=true padding=32 step=1 nx=false | ldc | 10.895–11.483x | 10.989–11.500x |
| type=float w=256 h=128 sn=true dn=false padding=32 step=1 nx=false | dmd | 15.065–15.634x | 15.315–15.807x |
| type=float w=256 h=128 sn=true dn=false padding=32 step=1 nx=false | ldc | 10.713–11.244x | 10.946–11.244x |
| type=float w=256 h=128 sn=true dn=true padding=32 step=1 nx=false | dmd | 15.131–16.859x | 15.049–17.044x |
| type=float w=256 h=128 sn=true dn=true padding=32 step=1 nx=false | ldc | 10.625–11.311x | 10.515–10.946x |
| type=float w=256 h=128 sn=false dn=false padding=0 step=1 nx=false | dmd | 15.663–16.781x | 15.663–16.967x |
| type=float w=256 h=128 sn=false dn=false padding=0 step=1 nx=false | ldc | 38.577–42.208x | 38.962–41.792x |
| type=float w=2048 h=512 sn=false dn=false padding=32 step=1 nx=false | dmd | 16.210–16.656x | 14.772–16.090x |
| type=float w=2048 h=512 sn=false dn=false padding=32 step=1 nx=false | ldc | 17.849–20.413x | 19.432–22.205x |
| type=float w=2048 h=512 sn=false dn=true padding=32 step=1 nx=false | dmd | 12.948–14.094x | 13.471–14.383x |
| type=float w=2048 h=512 sn=false dn=true padding=32 step=1 nx=false | ldc | 6.609–7.165x | 6.550–7.990x |
| type=float w=2048 h=512 sn=true dn=false padding=32 step=1 nx=false | dmd | 15.083–15.753x | 14.886–15.200x |
| type=float w=2048 h=512 sn=true dn=false padding=32 step=1 nx=false | ldc | 10.191–10.253x | 10.187–10.839x |
| type=float w=2048 h=512 sn=true dn=true padding=32 step=1 nx=false | dmd | 12.673–13.722x | 12.855–13.398x |
| type=float w=2048 h=512 sn=true dn=true padding=32 step=1 nx=false | ldc | 5.790–6.210x | 6.406–6.935x |
| type=float w=2048 h=512 sn=false dn=false padding=0 step=1 nx=false | dmd | 15.256–15.824x | 15.321–15.669x |
| type=float w=2048 h=512 sn=false dn=false padding=0 step=1 nx=false | ldc | 18.795–21.652x | 20.999–22.470x |
| type=ubyte w=31 h=17 sn=false dn=false padding=32 step=1 nx=false | dmd | 6.500–7.125x | 6.222–6.500x |
| type=ubyte w=31 h=17 sn=false dn=false padding=32 step=1 nx=false | ldc | 16.000–17.000x | 16.000–17.000x |
| type=ubyte w=31 h=17 sn=false dn=true padding=32 step=1 nx=false | dmd | 6.800–7.125x | 6.182–6.333x |
| type=ubyte w=31 h=17 sn=false dn=true padding=32 step=1 nx=false | ldc | 3.200–3.400x | 3.200–3.400x |
| type=ubyte w=31 h=17 sn=true dn=false padding=32 step=1 nx=false | dmd | 7.000–7.500x | 6.222–6.667x |
| type=ubyte w=31 h=17 sn=true dn=false padding=32 step=1 nx=false | ldc | 3.200–3.200x | 3.200–3.200x |
| type=ubyte w=31 h=17 sn=true dn=true padding=32 step=1 nx=false | dmd | 6.875–7.125x | 6.111–6.333x |
| type=ubyte w=31 h=17 sn=true dn=true padding=32 step=1 nx=false | ldc | 3.200–3.600x | 3.200–3.600x |
| type=ubyte w=31 h=17 sn=false dn=false padding=0 step=1 nx=false | dmd | 7.000–7.375x | 6.222–6.556x |
| type=ubyte w=31 h=17 sn=false dn=false padding=0 step=1 nx=false | ldc | 16.000–21.000x | 16.000–21.000x |
| type=ubyte w=256 h=128 sn=false dn=false padding=32 step=1 nx=false | dmd | 7.877–8.457x | 6.917–7.445x |
| type=ubyte w=256 h=128 sn=false dn=false padding=32 step=1 nx=false | ldc | 30.333–40.840x | 30.333–40.840x |
| type=ubyte w=256 h=128 sn=false dn=true padding=32 step=1 nx=false | dmd | 7.935–8.958x | 6.971–7.888x |
| type=ubyte w=256 h=128 sn=false dn=true padding=32 step=1 nx=false | ldc | 3.772–3.813x | 3.786–3.813x |
| type=ubyte w=256 h=128 sn=true dn=false padding=32 step=1 nx=false | dmd | 8.878–9.152x | 7.866–8.065x |
| type=ubyte w=256 h=128 sn=true dn=false padding=32 step=1 nx=false | ldc | 3.738–3.846x | 3.738–3.846x |
| type=ubyte w=256 h=128 sn=true dn=true padding=32 step=1 nx=false | dmd | 8.267–8.835x | 7.294–7.746x |
| type=ubyte w=256 h=128 sn=true dn=true padding=32 step=1 nx=false | ldc | 3.749–3.809x | 3.735–3.809x |
| type=ubyte w=256 h=128 sn=false dn=false padding=0 step=1 nx=false | dmd | 8.094–8.460x | 7.108–7.465x |
| type=ubyte w=256 h=128 sn=false dn=false padding=0 step=1 nx=false | ldc | 30.333–40.120x | 30.333–40.120x |
| type=ubyte w=2048 h=512 sn=false dn=false padding=32 step=1 nx=false | dmd | 7.320–8.000x | 6.909–7.084x |
| type=ubyte w=2048 h=512 sn=false dn=false padding=32 step=1 nx=false | ldc | 31.152–41.417x | 30.947–35.168x |
| type=ubyte w=2048 h=512 sn=false dn=true padding=32 step=1 nx=false | dmd | 7.538–8.317x | 6.574–7.181x |
| type=ubyte w=2048 h=512 sn=false dn=true padding=32 step=1 nx=false | ldc | 3.703–3.762x | 3.687–3.780x |
| type=ubyte w=2048 h=512 sn=true dn=false padding=32 step=1 nx=false | dmd | 7.756–8.012x | 6.420–7.061x |
| type=ubyte w=2048 h=512 sn=true dn=false padding=32 step=1 nx=false | ldc | 3.752–3.960x | 3.761–3.952x |
| type=ubyte w=2048 h=512 sn=true dn=true padding=32 step=1 nx=false | dmd | 7.907–8.130x | 6.811–6.925x |
| type=ubyte w=2048 h=512 sn=true dn=true padding=32 step=1 nx=false | ldc | 3.718–3.943x | 3.733–3.839x |
| type=ubyte w=2048 h=512 sn=false dn=false padding=0 step=1 nx=false | dmd | 7.634–8.405x | 6.853–7.258x |
| type=ubyte w=2048 h=512 sn=false dn=false padding=0 step=1 nx=false | ldc | 31.060–32.799x | 30.826–32.614x |
| type=float w=31 h=17 sn=false dn=true padding=32 step=2 nx=false | dmd | 1.000–1.022x | 0.662–1.022x |
| type=float w=31 h=17 sn=false dn=true padding=32 step=2 nx=false | ldc | 0.889–0.947x | 0.842–0.947x |
| type=float w=31 h=17 sn=true dn=false padding=32 step=2 nx=true | dmd | 1.000–1.043x | 1.000–1.043x |
| type=float w=31 h=17 sn=true dn=false padding=32 step=2 nx=true | ldc | 0.773–0.895x | 0.889–0.895x |
| type=ubyte w=31 h=17 sn=false dn=true padding=32 step=2 nx=false | dmd | 0.983–1.018x | 0.967–0.983x |
| type=ubyte w=31 h=17 sn=false dn=true padding=32 step=2 nx=false | ldc | 1.000–1.062x | 1.000–1.062x |
| type=ubyte w=31 h=17 sn=true dn=false padding=32 step=2 nx=true | dmd | 0.950–1.052x | 0.950–1.034x |
| type=ubyte w=31 h=17 sn=true dn=false padding=32 step=2 nx=true | ldc | 1.000–1.000x | 1.000–1.000x |
| type=Pod w=31 h=17 sn=false dn=true padding=32 step=2 nx=false | dmd | 1.017–1.070x | 1.000–1.034x |
| type=Pod w=31 h=17 sn=false dn=true padding=32 step=2 nx=false | ldc | 1.000–1.059x | 1.000–1.059x |
| type=Pod w=31 h=17 sn=true dn=false padding=32 step=2 nx=true | dmd | 1.070–1.088x | 0.984–1.051x |
| type=Pod w=31 h=17 sn=true dn=false padding=32 step=2 nx=true | ldc | 1.000–1.059x | 1.000–1.000x |
| type=Pod w=31 h=17 sn=false dn=false padding=32 step=1 nx=false | dmd | 1.968–2.032x | 1.968–2.032x |
| type=Pod w=31 h=17 sn=false dn=false padding=32 step=1 nx=false | ldc | 5.667–5.667x | 5.667–5.667x |
| type=Pod w=31 h=17 sn=false dn=true padding=32 step=1 nx=false | dmd | 1.903–1.935x | 1.903–1.935x |
| type=Pod w=31 h=17 sn=false dn=true padding=32 step=1 nx=false | ldc | 2.833–3.167x | 2.833–3.167x |
| type=Pod w=31 h=17 sn=true dn=false padding=32 step=1 nx=false | dmd | 1.871–1.968x | 1.871–1.968x |
| type=Pod w=31 h=17 sn=true dn=false padding=32 step=1 nx=false | ldc | 2.833–2.833x | 2.833–2.833x |
| type=Pod w=31 h=17 sn=true dn=true padding=32 step=1 nx=false | dmd | 1.903–2.000x | 1.903–2.000x |
| type=Pod w=31 h=17 sn=true dn=true padding=32 step=1 nx=false | ldc | 2.833–3.000x | 2.833–3.000x |
| type=Pod w=31 h=17 sn=false dn=false padding=0 step=1 nx=false | dmd | 1.903–2.032x | 1.903–2.032x |
| type=Pod w=31 h=17 sn=false dn=false padding=0 step=1 nx=false | ldc | 5.667–5.667x | 5.667–5.667x |
