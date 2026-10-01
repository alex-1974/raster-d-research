# Generic fill executor — xps evidence

Baseline: `d4763ff0b95999743ea43d0b1dcca44fc68773d1`.

All six independent processes pass 70 cases and special-float bit checks; all hashes match across processes and compilers. Invalid-plane/empty checks pass for float, ubyte and POD. Each case has two warmups and nine timed calls per path, with cyclic order and full output/padding checks outside timing.

Large (2048x512) baseline/candidate median ratios across three processes, including contiguous, padded, negative, repeated and overlapping Canonical rows:

| Type | Compiler | Pointer speedup range | Slice speedup range | Max public / pointer / slice median spread |
| --- | --- | --- | --- | --- |
| float | dmd | 8.431–13.234x | 9.232–13.845x | 16.84% / 72.61% / 61.67% |
| float | ldc | 2.281–16.557x | 2.247–16.350x | 13.11% / 96.17% / 73.32% |
| ubyte | dmd | 19.132–24.234x | 61.527–282.100x | 10.91% / 18.47% / 150.99% |
| ubyte | ldc | 8.628–144.913x | 11.892–151.867x | 9.27% / 355.03% / 157.86% |

XPS timing is reference-machine evidence, not a portable timing promise or AArch64 qualification. Small workloads and Universal fallback have no tight timing threshold. Preserve process spread when reviewing source-form selection.

Tiny cases can be below clock resolution: zero raw samples are retained and zero-median ratios are omitted. All large-case samples must be positive.

## Per-case paired ratios

| Case | Compiler | Pointer range | Slice range |
| --- | --- | --- | --- |
| type=float w=31 h=17 layout=contiguous | dmd | 11.333–11.333x | 11.333–11.333x |
| type=float w=31 h=17 layout=contiguous | ldc | below clock resolution | 6.000–7.000x |
| type=float w=31 h=17 layout=padded | dmd | 11.333–11.667x | 11.333–11.667x |
| type=float w=31 h=17 layout=padded | ldc | below clock resolution | 6.000–6.000x |
| type=float w=31 h=17 layout=negative-row | dmd | 11.333–11.333x | 11.333–11.333x |
| type=float w=31 h=17 layout=negative-row | ldc | below clock resolution | 6.000–6.000x |
| type=float w=31 h=17 layout=repeated-row | dmd | 11.333–17.000x | 11.333–11.667x |
| type=float w=31 h=17 layout=repeated-row | ldc | below clock resolution | below clock resolution |
| type=float w=31 h=17 layout=overlap-row | dmd | 11.333–17.000x | 11.333–11.333x |
| type=float w=31 h=17 layout=overlap-row | ldc | below clock resolution | below clock resolution |
| type=float w=31 h=17 layout=overlap-negative | dmd | 11.333–17.000x | 11.333–11.667x |
| type=float w=31 h=17 layout=overlap-negative | ldc | below clock resolution | 6.000–7.000x |
| type=float w=31 h=17 layout=universal | dmd | 0.971–0.972x | 0.971–0.972x |
| type=float w=31 h=17 layout=universal | ldc | 0.750–1.000x | 1.000–1.000x |
| type=float w=31 h=17 layout=universal-negative | dmd | 0.971–0.972x | 0.971–0.972x |
| type=float w=31 h=17 layout=universal-negative | ldc | 0.750–1.000x | 1.000–1.000x |
| type=float w=31 h=17 layout=zero-sample | dmd | 0.971–0.973x | 0.971–0.973x |
| type=float w=31 h=17 layout=zero-sample | ldc | 1.000–1.000x | 0.857–1.000x |
| type=float w=31 h=17 layout=zero-both | dmd | 0.971–1.000x | 0.971–1.000x |
| type=float w=31 h=17 layout=zero-both | ldc | 0.857–1.000x | 1.000–1.000x |
| type=float w=256 h=128 layout=contiguous | dmd | 12.533–12.828x | 12.312–12.596x |
| type=float w=256 h=128 layout=contiguous | ldc | 8.809–10.744x | 8.809–10.615x |
| type=float w=256 h=128 layout=padded | dmd | 12.534–12.760x | 12.307–12.476x |
| type=float w=256 h=128 layout=padded | ldc | 7.086–10.049x | 7.904–10.300x |
| type=float w=256 h=128 layout=negative-row | dmd | 12.540–12.665x | 12.313–12.368x |
| type=float w=256 h=128 layout=negative-row | ldc | 10.073–10.220x | 9.833–10.220x |
| type=float w=256 h=128 layout=repeated-row | dmd | 13.072–13.444x | 12.765–13.120x |
| type=float w=256 h=128 layout=repeated-row | ldc | 16.320–16.792x | 16.320–16.792x |
| type=float w=256 h=128 layout=overlap-row | dmd | 12.613–12.946x | 12.386–12.675x |
| type=float w=256 h=128 layout=overlap-row | ldc | 12.235–12.625x | 12.242–12.909x |
| type=float w=256 h=128 layout=overlap-negative | dmd | 12.534–12.695x | 12.301–12.471x |
| type=float w=256 h=128 layout=overlap-negative | ldc | 12.152–12.606x | 12.152–12.382x |
| type=float w=256 h=128 layout=universal | dmd | 0.963–0.991x | 0.967–0.994x |
| type=float w=256 h=128 layout=universal | ldc | 0.995–1.023x | 1.000–1.012x |
| type=float w=256 h=128 layout=universal-negative | dmd | 0.936–0.963x | 0.965–0.967x |
| type=float w=256 h=128 layout=universal-negative | ldc | 0.998–1.027x | 1.010–1.019x |
| type=float w=256 h=128 layout=zero-sample | dmd | 0.942–0.963x | 0.962–0.967x |
| type=float w=256 h=128 layout=zero-sample | ldc | 0.986–1.005x | 1.000–1.002x |
| type=float w=256 h=128 layout=zero-both | dmd | 0.952–0.967x | 0.948–0.967x |
| type=float w=256 h=128 layout=zero-both | ldc | 0.998–1.000x | 1.000–1.078x |
| type=float w=2048 h=512 layout=contiguous | dmd | 10.537–12.924x | 10.108–12.889x |
| type=float w=2048 h=512 layout=contiguous | ldc | 3.585–4.250x | 3.562–4.506x |
| type=float w=2048 h=512 layout=padded | dmd | 10.226–13.098x | 12.851–13.012x |
| type=float w=2048 h=512 layout=padded | ldc | 2.328–4.136x | 2.247–3.920x |
| type=float w=2048 h=512 layout=negative-row | dmd | 8.431–12.557x | 9.232–12.774x |
| type=float w=2048 h=512 layout=negative-row | ldc | 2.281–4.118x | 3.261–4.291x |
| type=float w=2048 h=512 layout=repeated-row | dmd | 13.000–13.178x | 12.915–13.845x |
| type=float w=2048 h=512 layout=repeated-row | ldc | 15.092–16.557x | 15.092–16.350x |
| type=float w=2048 h=512 layout=overlap-row | dmd | 12.894–13.234x | 12.875–13.224x |
| type=float w=2048 h=512 layout=overlap-row | ldc | 7.809–9.299x | 7.586–9.412x |
| type=float w=2048 h=512 layout=overlap-negative | dmd | 12.951–13.158x | 12.846–13.093x |
| type=float w=2048 h=512 layout=overlap-negative | ldc | 8.680–9.582x | 7.448–9.666x |
| type=float w=2048 h=512 layout=universal | dmd | 0.939–0.964x | 0.957–0.968x |
| type=float w=2048 h=512 layout=universal | ldc | 0.856–0.987x | 0.950–1.015x |
| type=float w=2048 h=512 layout=universal-negative | dmd | 0.903–0.963x | 0.962–0.975x |
| type=float w=2048 h=512 layout=universal-negative | ldc | 0.844–1.000x | 0.932–1.004x |
| type=float w=2048 h=512 layout=zero-sample | dmd | 0.956–0.969x | 0.947–0.963x |
| type=float w=2048 h=512 layout=zero-sample | ldc | 0.976–1.009x | 0.980–1.000x |
| type=float w=2048 h=512 layout=zero-both | dmd | 0.949–0.996x | 0.964–1.004x |
| type=float w=2048 h=512 layout=zero-both | ldc | 1.002–1.013x | 1.002–1.021x |
| type=ubyte w=31 h=17 layout=contiguous | dmd | 15.000–29.000x | 9.667–13.500x |
| type=ubyte w=31 h=17 layout=contiguous | ldc | below clock resolution | below clock resolution |
| type=ubyte w=31 h=17 layout=padded | dmd | 15.000–30.000x | 10.000–15.000x |
| type=ubyte w=31 h=17 layout=padded | ldc | below clock resolution | below clock resolution |
| type=ubyte w=31 h=17 layout=negative-row | dmd | 15.500–29.000x | 9.667–14.000x |
| type=ubyte w=31 h=17 layout=negative-row | ldc | below clock resolution | below clock resolution |
| type=ubyte w=31 h=17 layout=repeated-row | dmd | 15.000–30.000x | 10.000–15.000x |
| type=ubyte w=31 h=17 layout=repeated-row | ldc | below clock resolution | below clock resolution |
| type=ubyte w=31 h=17 layout=overlap-row | dmd | 15.500–30.000x | 10.333–15.000x |
| type=ubyte w=31 h=17 layout=overlap-row | ldc | below clock resolution | below clock resolution |
| type=ubyte w=31 h=17 layout=overlap-negative | dmd | 15.500–29.000x | 10.333–14.500x |
| type=ubyte w=31 h=17 layout=overlap-negative | ldc | below clock resolution | below clock resolution |
| type=ubyte w=31 h=17 layout=universal | dmd | 0.968–1.036x | 1.000–1.000x |
| type=ubyte w=31 h=17 layout=universal | ldc | 1.000–1.000x | 1.000–1.000x |
| type=ubyte w=31 h=17 layout=universal-negative | dmd | 0.968–1.000x | 0.903–1.000x |
| type=ubyte w=31 h=17 layout=universal-negative | ldc | 1.000–1.000x | 1.000–1.000x |
| type=ubyte w=31 h=17 layout=zero-sample | dmd | 0.967–1.000x | 0.879–1.000x |
| type=ubyte w=31 h=17 layout=zero-sample | ldc | 1.000–1.000x | 0.857–1.000x |
| type=ubyte w=31 h=17 layout=zero-both | dmd | 0.964–1.000x | 0.871–1.000x |
| type=ubyte w=31 h=17 layout=zero-both | ldc | 1.000–1.000x | 1.000–1.000x |
| type=ubyte w=256 h=128 layout=contiguous | dmd | 20.877–21.632x | 53.600–60.710x |
| type=ubyte w=256 h=128 layout=contiguous | ldc | 34.083–48.750x | 29.214–48.750x |
| type=ubyte w=256 h=128 layout=padded | dmd | 20.789–26.325x | 53.457–75.345x |
| type=ubyte w=256 h=128 layout=padded | ldc | 26.667–43.333x | 22.222–45.667x |
| type=ubyte w=256 h=128 layout=negative-row | dmd | 17.542–23.012x | 46.925–64.276x |
| type=ubyte w=256 h=128 layout=negative-row | ldc | 39.900–43.333x | 43.333–45.778x |
| type=ubyte w=256 h=128 layout=repeated-row | dmd | 20.582–24.413x | 60.400–69.750x |
| type=ubyte w=256 h=128 layout=repeated-row | ldc | 97.000–101.750x | 97.000–101.750x |
| type=ubyte w=256 h=128 layout=overlap-row | dmd | 20.435–21.058x | 55.294–60.393x |
| type=ubyte w=256 h=128 layout=overlap-row | ldc | 25.562–58.429x | 31.462–58.429x |
| type=ubyte w=256 h=128 layout=overlap-negative | dmd | 20.840–22.742x | 58.774–63.250x |
| type=ubyte w=256 h=128 layout=overlap-negative | ldc | 56.571–58.714x | 57.143–66.000x |
| type=ubyte w=256 h=128 layout=universal | dmd | 0.925–0.998x | 0.955–1.087x |
| type=ubyte w=256 h=128 layout=universal | ldc | 1.002–1.012x | 0.990–1.013x |
| type=ubyte w=256 h=128 layout=universal-negative | dmd | 0.964–0.988x | 0.974–1.002x |
| type=ubyte w=256 h=128 layout=universal-negative | ldc | 1.000–1.015x | 1.002–1.029x |
| type=ubyte w=256 h=128 layout=zero-sample | dmd | 0.986–1.007x | 0.905–1.004x |
| type=ubyte w=256 h=128 layout=zero-sample | ldc | 0.981–1.003x | 1.000–1.000x |
| type=ubyte w=256 h=128 layout=zero-both | dmd | 1.003–1.039x | 0.908–1.036x |
| type=ubyte w=256 h=128 layout=zero-both | ldc | 0.997–1.005x | 1.000–1.000x |
| type=ubyte w=2048 h=512 layout=contiguous | dmd | 19.132–21.945x | 61.527–149.507x |
| type=ubyte w=2048 h=512 layout=contiguous | ldc | 8.628–35.929x | 16.585–35.718x |
| type=ubyte w=2048 h=512 layout=padded | dmd | 20.948–21.139x | 83.194–175.225x |
| type=ubyte w=2048 h=512 layout=padded | ldc | 8.794–23.643x | 13.089–32.192x |
| type=ubyte w=2048 h=512 layout=negative-row | dmd | 20.813–22.429x | 104.490–201.218x |
| type=ubyte w=2048 h=512 layout=negative-row | ldc | 9.472–25.092x | 11.892–26.034x |
| type=ubyte w=2048 h=512 layout=repeated-row | dmd | 23.992–24.234x | 275.199–282.100x |
| type=ubyte w=2048 h=512 layout=repeated-row | ldc | 48.297–144.913x | 141.380–151.867x |
| type=ubyte w=2048 h=512 layout=overlap-row | dmd | 21.982–23.171x | 125.275–232.975x |
| type=ubyte w=2048 h=512 layout=overlap-row | ldc | 35.736–38.656x | 35.303–42.443x |
| type=ubyte w=2048 h=512 layout=overlap-negative | dmd | 21.603–23.216x | 156.315–210.405x |
| type=ubyte w=2048 h=512 layout=overlap-negative | ldc | 28.000–40.654x | 32.632–40.528x |
| type=ubyte w=2048 h=512 layout=universal | dmd | 0.993–1.014x | 0.968–1.013x |
| type=ubyte w=2048 h=512 layout=universal | ldc | 0.988–1.017x | 0.983–1.004x |
| type=ubyte w=2048 h=512 layout=universal-negative | dmd | 0.978–1.030x | 0.991–1.040x |
| type=ubyte w=2048 h=512 layout=universal-negative | ldc | 0.951–1.010x | 0.979–1.002x |
| type=ubyte w=2048 h=512 layout=zero-sample | dmd | 0.977–1.015x | 0.983–1.018x |
| type=ubyte w=2048 h=512 layout=zero-sample | ldc | 0.988–1.018x | 1.000–1.006x |
| type=ubyte w=2048 h=512 layout=zero-both | dmd | 0.982–1.084x | 0.992–1.170x |
| type=ubyte w=2048 h=512 layout=zero-both | ldc | 0.995–1.004x | 0.991–1.000x |
| type=Pod w=31 h=17 layout=contiguous | dmd | 16.667–17.500x | 3.846–4.250x |
| type=Pod w=31 h=17 layout=contiguous | ldc | 6.000–9.000x | 6.000–9.000x |
| type=Pod w=31 h=17 layout=padded | dmd | 13.750–17.500x | 3.929–4.375x |
| type=Pod w=31 h=17 layout=padded | ldc | 6.000–6.000x | 6.000–6.000x |
| type=Pod w=31 h=17 layout=negative-row | dmd | 14.000–17.500x | 4.000–4.375x |
| type=Pod w=31 h=17 layout=negative-row | ldc | 6.000–6.000x | 6.000–6.000x |
| type=Pod w=31 h=17 layout=repeated-row | dmd | 16.333–34.000x | 3.769–4.250x |
| type=Pod w=31 h=17 layout=repeated-row | ldc | 6.000–6.000x | 6.000–6.000x |
| type=Pod w=31 h=17 layout=overlap-row | dmd | 17.000–17.000x | 3.923–4.250x |
| type=Pod w=31 h=17 layout=overlap-row | ldc | below clock resolution | 6.000–6.000x |
| type=Pod w=31 h=17 layout=overlap-negative | dmd | 14.000–17.000x | 4.250–4.308x |
| type=Pod w=31 h=17 layout=overlap-negative | ldc | below clock resolution | 6.000–6.000x |
| type=Pod w=31 h=17 layout=universal | dmd | 1.057–1.120x | 1.029–1.057x |
| type=Pod w=31 h=17 layout=universal | ldc | 0.857–1.167x | 0.857–1.167x |
| type=Pod w=31 h=17 layout=universal-negative | dmd | 1.029–1.098x | 1.029–1.077x |
| type=Pod w=31 h=17 layout=universal-negative | ldc | 0.857–1.167x | 1.000–1.167x |
| type=Pod w=31 h=17 layout=zero-sample | dmd | 1.030–1.078x | 1.030–1.078x |
| type=Pod w=31 h=17 layout=zero-sample | ldc | 1.000–1.000x | 1.000–1.000x |
| type=Pod w=31 h=17 layout=zero-both | dmd | 1.030–1.077x | 1.030–1.077x |
| type=Pod w=31 h=17 layout=zero-both | ldc | 1.000–1.000x | 1.000–1.000x |
