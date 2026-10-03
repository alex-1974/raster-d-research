# Full public copy/conversion candidates — container evidence

Production: `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`. All six processes pass 96 timed cases, 32 extra semantic cases and public controls for all four public paths. Source/output hashes match across compilers/processes.

Bounds, Execute and Combined are complete pinned public consumers, changing only conservative relation rejection and/or unit-sample-stride row execution (plus already-approved flat conversion). Original Universal execution, errors, injectivity, overlap and arithmetic-failure fallback remain. C++ is execution-only and omits validation while adding a separate C ABI call; it is not a complete-library comparison. No reassociation/precision change, compiler switch, explicit SIMD or threading.

Fifteen cyclic rounds rotate five paths through every order position three times. Two warmups; reset and full backing checks are outside each timer. All large samples are positive; tiny zero medians retain data and omit ratios. VM is diagnostic, XPS is required for promotion; AArch64 unqualified.

| Case | Compiler | Public/Bounds | Public/Execute | Public/Combined | Combined/C++ | Public/Combined process spread |
| --- | --- | --- | --- | --- | --- | --- |
| op=copy-ubyte w=31 h=17 layout=contiguous | dmd | below clock resolution | below clock resolution | below clock resolution | below clock resolution | below clock resolution / below clock resolution |
| op=copy-ubyte w=31 h=17 layout=contiguous | ldc | below clock resolution | below clock resolution | below clock resolution | below clock resolution | below clock resolution / below clock resolution |
| op=copy-float w=31 h=17 layout=contiguous | dmd | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | below clock resolution | 0.00% / 0.00% |
| op=copy-float w=31 h=17 layout=contiguous | ldc | below clock resolution | below clock resolution | below clock resolution | below clock resolution | below clock resolution / below clock resolution |
| op=copy-Pod w=31 h=17 layout=contiguous | dmd | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 0.00% / 0.00% |
| op=copy-Pod w=31 h=17 layout=contiguous | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 0.00% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=contiguous | dmd | 1.000–1.000x | 10.333–10.333x | 10.333–10.333x | 3.000–3.000x | 0.00% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=contiguous | ldc | 1.000–1.000x | 20.000–20.000x | 20.000–20.000x | 1.000–1.000x | 0.00% / 0.00% |
| op=copy-ubyte w=31 h=17 layout=padded | dmd | 21.795–21.907x | 1.024–1.053x | 469.500–479.500x | below clock resolution | 2.13% / 0.00% |
| op=copy-ubyte w=31 h=17 layout=padded | ldc | 37.636–37.727x | 1.022–1.022x | 207.000–207.500x | below clock resolution | 0.24% / 0.00% |
| op=copy-float w=31 h=17 layout=padded | dmd | 20.756–21.511x | 1.016–1.056x | 311.333–322.667x | below clock resolution | 3.64% / 0.00% |
| op=copy-float w=31 h=17 layout=padded | ldc | 34.583–37.727x | 1.022–1.022x | 207.000–207.500x | below clock resolution | 0.24% / 0.00% |
| op=copy-Pod w=31 h=17 layout=padded | dmd | 20.804–21.511x | 1.034–1.052x | 191.400–242.000x | 4.000–5.000x | 2.65% / 25.00% |
| op=copy-Pod w=31 h=17 layout=padded | ldc | 32.077–34.667x | 1.025–1.027x | 138.333–139.000x | below clock resolution | 0.48% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=padded | dmd | 104.500–106.468x | 0.973–1.040x | 704.571–801.167x | 6.000–7.000x | 4.10% / 16.67% |
| op=convert-ubyte-float w=31 h=17 layout=padded | ldc | 127.308–135.667x | 0.894–1.016x | 551.667–1628.000x | 1.000–3.000x | 1.72% / 200.00% |
| op=copy-ubyte w=31 h=17 layout=negative-source | dmd | 21.133–22.279x | 1.020–1.064x | 317.000–479.000x | below clock resolution | 3.23% / 50.00% |
| op=copy-ubyte w=31 h=17 layout=negative-source | ldc | 34.667–37.727x | 1.022–1.025x | 207.000–208.000x | below clock resolution | 0.48% / 0.00% |
| op=copy-float w=31 h=17 layout=negative-source | dmd | 20.644–21.289x | 1.033–1.047x | 309.667–319.333x | below clock resolution | 3.12% / 0.00% |
| op=copy-float w=31 h=17 layout=negative-source | ldc | 34.583–34.667x | 1.022–1.025x | 207.500–208.000x | below clock resolution | 0.24% / 0.00% |
| op=copy-Pod w=31 h=17 layout=negative-source | dmd | 21.244–21.432x | 1.029–1.060x | 191.200–235.750x | 4.000–5.000x | 2.03% / 25.00% |
| op=copy-Pod w=31 h=17 layout=negative-source | ldc | 32.000–34.667x | 1.025–1.027x | 138.667–138.667x | below clock resolution | 0.00% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=negative-source | dmd | 100.479–111.362x | 1.002–1.088x | 747.714–803.833x | 6.000–7.000x | 9.82% / 16.67% |
| op=convert-ubyte-float w=31 h=17 layout=negative-source | ldc | 135.083–138.333x | 1.011–1.020x | 540.333–553.333x | 3.000–3.000x | 2.41% / 0.00% |
| op=copy-ubyte w=31 h=17 layout=negative-both | dmd | 21.182–22.524x | 1.000–1.065x | 310.667–473.000x | below clock resolution | 4.40% / 50.00% |
| op=copy-ubyte w=31 h=17 layout=negative-both | ldc | 37.545–37.636x | 1.022–1.025x | 206.500–207.000x | below clock resolution | 0.24% / 0.00% |
| op=copy-float w=31 h=17 layout=negative-both | dmd | 20.733–22.000x | 0.999–1.079x | 311.000–322.667x | below clock resolution | 3.75% / 0.00% |
| op=copy-float w=31 h=17 layout=negative-both | ldc | 34.500–34.583x | 1.022–1.025x | 207.000–207.500x | below clock resolution | 0.24% / 0.00% |
| op=copy-Pod w=31 h=17 layout=negative-both | dmd | 20.867–22.295x | 1.013–1.085x | 234.750–245.250x | 4.000–4.000x | 4.47% / 0.00% |
| op=copy-Pod w=31 h=17 layout=negative-both | ldc | 31.923–34.583x | 1.025–1.025x | 138.333–138.333x | below clock resolution | 0.00% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=negative-both | dmd | 102.146–103.688x | 0.997–1.026x | 678.714–817.167x | 6.000–7.000x | 4.76% / 16.67% |
| op=convert-ubyte-float w=31 h=17 layout=negative-both | ldc | 135.000–137.250x | 1.009–1.014x | 540.000–549.000x | 3.000–3.000x | 1.67% / 0.00% |
| op=copy-ubyte w=31 h=17 layout=universal | dmd | 21.674–22.070x | 0.969–1.006x | 21.182–22.070x | 2.688–2.750x | 2.68% / 2.33% |
| op=copy-ubyte w=31 h=17 layout=universal | ldc | 37.636–37.727x | 0.988–0.990x | 25.875–25.938x | 0.941–1.000x | 0.24% / 0.00% |
| op=copy-float w=31 h=17 layout=universal | dmd | 20.630–21.467x | 0.975–1.023x | 21.364–21.568x | 2.588–2.647x | 2.77% / 2.27% |
| op=copy-float w=31 h=17 layout=universal | ldc | 34.583–37.727x | 0.993–0.993x | 27.667–27.667x | 0.882–0.882x | 0.00% / 0.00% |
| op=copy-Pod w=31 h=17 layout=universal | dmd | 21.159–21.333x | 0.992–1.016x | 20.239–21.333x | 2.368–2.611x | 3.11% / 4.44% |
| op=copy-Pod w=31 h=17 layout=universal | ldc | 32.692–34.583x | 0.988–0.991x | 24.412–25.000x | 1.000–1.000x | 2.41% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=universal | dmd | 58.370–60.739x | 0.961–1.035x | 59.667–62.000x | 15.000–15.333x | 4.06% / 2.22% |
| op=convert-ubyte-float w=31 h=17 layout=universal | ldc | 79.500–80.833x | 1.005–1.008x | 63.600–64.667x | 5.000–5.000x | 1.68% / 0.00% |
| op=copy-ubyte w=31 h=17 layout=universal-negative | dmd | 22.114–22.721x | 0.979–1.000x | 22.023–22.205x | 2.750–2.750x | 0.83% / 0.00% |
| op=copy-ubyte w=31 h=17 layout=universal-negative | ldc | 37.000–37.182x | 0.988–0.990x | 25.438–25.562x | 0.941–1.000x | 0.49% / 0.00% |
| op=copy-float w=31 h=17 layout=universal-negative | dmd | 21.333–22.556x | 0.973–1.050x | 21.333–22.556x | 2.368–2.647x | 5.73% / 0.00% |
| op=copy-float w=31 h=17 layout=universal-negative | ldc | 34.000–34.917x | 0.993–0.995x | 27.200–27.933x | 0.882–0.882x | 2.70% / 0.00% |
| op=copy-Pod w=31 h=17 layout=universal-negative | dmd | 21.304–21.955x | 0.989–1.009x | 20.553–20.979x | 2.611–2.765x | 2.07% / 0.00% |
| op=copy-Pod w=31 h=17 layout=universal-negative | ldc | 29.286–34.167x | 0.988–0.993x | 21.579–22.778x | 1.059–1.118x | 0.24% / 5.56% |
| op=convert-ubyte-float w=31 h=17 layout=universal-negative | dmd | 61.898–67.723x | 0.926–1.043x | 64.532–69.196x | 15.333–15.667x | 5.40% / 2.17% |
| op=convert-ubyte-float w=31 h=17 layout=universal-negative | ldc | 81.417–83.083x | 1.003–1.009x | 65.133–66.467x | 5.000–5.000x | 2.05% / 0.00% |
| op=copy-ubyte w=31 h=17 layout=repeated-source | dmd | 21.133–21.791x | 1.034–1.053x | 312.333–474.000x | below clock resolution | 1.49% / 50.00% |
| op=copy-ubyte w=31 h=17 layout=repeated-source | ldc | 37.636–37.727x | 1.022–1.022x | 207.000–207.500x | below clock resolution | 0.24% / 0.00% |
| op=copy-float w=31 h=17 layout=repeated-source | dmd | 21.818–22.222x | 1.002–1.046x | 333.333–496.000x | below clock resolution | 4.17% / 50.00% |
| op=copy-float w=31 h=17 layout=repeated-source | ldc | 34.333–34.583x | 1.025–1.025x | 206.000–207.500x | below clock resolution | 0.73% / 0.00% |
| op=copy-Pod w=31 h=17 layout=repeated-source | dmd | 21.909–22.333x | 1.001–1.066x | 241.000–251.250x | 4.000–4.000x | 4.25% / 0.00% |
| op=copy-Pod w=31 h=17 layout=repeated-source | ldc | 31.769–34.583x | 1.022–1.027x | 137.000–138.333x | 3.000–3.000x | 0.97% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=repeated-source | dmd | 99.125–104.848x | 0.962–1.022x | 791.500–803.833x | 6.000–6.000x | 1.56% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=repeated-source | ldc | 135.583–137.667x | 1.012–1.012x | 813.500–826.000x | 2.000–2.000x | 1.54% / 0.00% |
| op=copy-ubyte w=31 h=17 layout=zero-source | dmd | 5.907–6.071x | 0.996–1.000x | 5.644–5.930x | 2.647–2.688x | 0.39% / 4.65% |
| op=copy-ubyte w=31 h=17 layout=zero-source | ldc | 8.417–9.091x | 0.952–0.962x | 6.250–6.312x | 1.000–1.000x | 1.00% / 0.00% |
| op=copy-float w=31 h=17 layout=zero-source | dmd | 6.378–6.422x | 0.997–1.000x | 6.283–6.568x | 2.316–2.588x | 0.70% / 4.55% |
| op=copy-float w=31 h=17 layout=zero-source | ldc | 8.750–8.917x | 0.963–0.973x | 7.000–7.133x | 0.789–0.882x | 1.90% / 0.00% |
| op=copy-Pod w=31 h=17 layout=zero-source | dmd | 6.523–6.698x | 0.997–1.000x | 6.378–6.545x | 2.316–2.647x | 0.35% / 2.27% |
| op=copy-Pod w=31 h=17 layout=zero-source | ldc | 8.917–8.917x | 0.955–0.964x | 6.294–6.688x | 0.895–1.000x | 0.00% / 6.25% |
| op=convert-ubyte-float w=31 h=17 layout=zero-source | dmd | 16.370–16.711x | 0.992–0.999x | 17.091–17.136x | 14.667–14.667x | 0.27% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=zero-source | ldc | 23.250–23.583x | 1.022–1.029x | 18.600–18.867x | 5.000–5.000x | 1.43% / 0.00% |
| op=copy-ubyte w=256 h=128 layout=contiguous | dmd | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 0.00% / 0.00% |
| op=copy-ubyte w=256 h=128 layout=contiguous | ldc | 1.000–1.167x | 1.000–1.167x | 1.000–1.167x | 0.857–0.857x | 16.67% / 0.00% |
| op=copy-float w=256 h=128 layout=contiguous | dmd | 1.000–1.042x | 1.042–1.042x | 1.042–1.042x | 1.043–1.043x | 0.00% / 0.00% |
| op=copy-float w=256 h=128 layout=contiguous | ldc | 1.000–1.000x | 0.958–1.043x | 1.000–1.043x | 1.000–1.045x | 4.35% / 0.00% |
| op=copy-Pod w=256 h=128 layout=contiguous | dmd | 0.982–1.039x | 0.964–1.038x | 0.932–1.000x | 1.038–1.180x | 3.77% / 11.32% |
| op=copy-Pod w=256 h=128 layout=contiguous | ldc | 1.000–1.000x | 1.020–1.038x | 0.942–1.059x | 1.020–1.104x | 10.20% / 3.92% |
| op=convert-ubyte-float w=256 h=128 layout=contiguous | dmd | 0.970–1.000x | 10.309–10.383x | 10.367–10.383x | 6.000–6.000x | 0.16% / 0.00% |
| op=convert-ubyte-float w=256 h=128 layout=contiguous | ldc | 0.998–1.001x | 18.552–43.034x | 18.552–43.034x | 1.071–2.393x | 0.40% / 131.03% |
| op=copy-ubyte w=256 h=128 layout=padded | dmd | 21.545–21.919x | 1.034–1.063x | 2013.036–2120.444x | 2.154–2.700x | 1.57% / 3.70% |
| op=copy-ubyte w=256 h=128 layout=padded | ldc | 36.082–38.175x | 1.020–1.063x | 1133.318–1182.227x | 3.143–3.286x | 5.95% / 4.55% |
| op=copy-float w=256 h=128 layout=padded | dmd | 20.801–21.537x | 1.038–1.079x | 1306.140–1568.676x | 1.233–1.357x | 3.34% / 16.22% |
| op=copy-float w=256 h=128 layout=padded | ldc | 33.468–37.085x | 1.009–1.042x | 715.257–791.882x | 1.320–1.400x | 7.55% / 6.06% |
| op=copy-Pod w=256 h=128 layout=padded | dmd | 20.349–21.911x | 1.030–1.041x | 698.253–837.290x | 1.095–1.317x | 3.34% / 20.29% |
| op=copy-Pod w=256 h=128 layout=padded | ldc | 32.654–35.359x | 0.981–1.049x | 398.730–429.569x | 1.160–1.167x | 6.30% / 10.34% |
| op=convert-ubyte-float w=256 h=128 layout=padded | dmd | 103.717–196.086x | 1.006–1.032x | 1348.000–2728.474x | 6.871–7.133x | 100.51% / 1.42% |
| op=convert-ubyte-float w=256 h=128 layout=padded | ldc | 133.640–143.747x | 1.007–1.018x | 1375.375–2723.821x | 1.258–2.323x | 7.27% / 84.62% |
| op=copy-ubyte w=256 h=128 layout=negative-source | dmd | 21.499–51.928x | 1.046–1.393x | 2064.655–4154.212x | 2.071–2.700x | 142.49% / 22.22% |
| op=copy-ubyte w=256 h=128 layout=negative-source | ldc | 35.013–37.924x | 0.996–1.050x | 1117.955–1147.095x | 2.625–3.286x | 9.26% / 9.52% |
| op=copy-float w=256 h=128 layout=negative-source | dmd | 20.795–47.320x | 1.065–1.122x | 1461.667–2850.298x | 1.233–1.343x | 136.75% / 27.03% |
| op=copy-float w=256 h=128 layout=negative-source | ldc | 33.747–34.739x | 1.009–1.018x | 703.222–730.857x | 1.400–1.440x | 1.41% / 2.86% |
| op=copy-Pod w=256 h=128 layout=negative-source | dmd | 21.070–54.512x | 1.024–1.079x | 650.061–1587.440x | 1.167–1.333x | 158.43% / 28.95% |
| op=copy-Pod w=256 h=128 layout=negative-source | ldc | 32.915–35.486x | 0.989–1.061x | 405.770–454.586x | 1.036–1.196x | 7.38% / 5.17% |
| op=convert-ubyte-float w=256 h=128 layout=negative-source | dmd | 101.999–206.949x | 1.017–1.052x | 1328.398–2742.551x | 6.382–6.485x | 109.39% / 2.84% |
| op=convert-ubyte-float w=256 h=128 layout=negative-source | ldc | 133.966–148.807x | 1.001–1.025x | 731.890–806.580x | 4.059–4.281x | 11.83% / 1.47% |
| op=copy-ubyte w=256 h=128 layout=negative-both | dmd | 21.509–40.252x | 1.035–1.125x | 1820.938–3069.514x | 2.333–3.111x | 90.27% / 25.00% |
| op=copy-ubyte w=256 h=128 layout=negative-both | ldc | 35.993–37.478x | 1.033–1.051x | 1117.826–1189.476x | 3.000–3.286x | 2.93% / 9.52% |
| op=copy-float w=256 h=128 layout=negative-both | dmd | 20.046–36.086x | 0.722–1.059x | 1343.523–2116.522x | 1.257–1.438x | 71.58% / 21.05% |
| op=copy-float w=256 h=128 layout=negative-both | ldc | 33.942–37.587x | 1.043–1.119x | 735.735–808.118x | 1.400–1.417x | 10.21% / 2.94% |
| op=copy-Pod w=256 h=128 layout=negative-both | dmd | 21.214–51.022x | 1.028–1.427x | 774.618–1375.520x | 1.175–1.225x | 141.61% / 46.27% |
| op=copy-Pod w=256 h=128 layout=negative-both | ldc | 32.175–40.477x | 0.956–1.159x | 419.097–485.079x | 1.140–1.189x | 26.81% / 10.53% |
| op=convert-ubyte-float w=256 h=128 layout=negative-both | dmd | 104.022–206.148x | 1.003–1.034x | 1342.919–2617.313x | 6.029–6.903x | 97.67% / 1.42% |
| op=convert-ubyte-float w=256 h=128 layout=negative-both | ldc | 134.411–144.611x | 1.004–1.024x | 733.331–754.406x | 4.088–4.387x | 8.17% / 5.15% |
| op=copy-ubyte w=256 h=128 layout=universal | dmd | 21.196–48.075x | 0.995–1.300x | 21.016–47.514x | 2.670–2.703x | 125.41% / 1.52% |
| op=copy-ubyte w=256 h=128 layout=universal | ldc | 34.987–38.822x | 0.949–1.050x | 23.845–27.156x | 1.011–1.025x | 12.41% / 1.31% |
| op=copy-float w=256 h=128 layout=universal | dmd | 20.961–35.936x | 0.990–1.035x | 19.795–35.633x | 2.533–2.644x | 72.78% / 4.18% |
| op=copy-float w=256 h=128 layout=universal | ldc | 33.197–34.933x | 0.971–1.013x | 26.020–27.902x | 0.876–0.877x | 7.23% / 0.11% |
| op=copy-Pod w=256 h=128 layout=universal | dmd | 22.684–51.497x | 1.015–1.065x | 20.976–50.269x | 2.507–2.625x | 129.34% / 6.26% |
| op=copy-Pod w=256 h=128 layout=universal | ldc | 31.967–34.732x | 0.907–1.019x | 22.792–25.190x | 0.963–1.028x | 3.99% / 6.44% |
| op=convert-ubyte-float w=256 h=128 layout=universal | dmd | 60.704–117.908x | 0.964–1.024x | 61.785–119.397x | 14.710–15.388x | 93.10% / 4.61% |
| op=convert-ubyte-float w=256 h=128 layout=universal | ldc | 78.503–82.076x | 0.998–1.030x | 61.647–65.137x | 4.984–5.164x | 4.88% / 0.74% |
| op=copy-ubyte w=256 h=128 layout=universal-negative | dmd | 19.481–36.788x | 0.730–0.988x | 21.639–35.514x | 2.703–2.782x | 67.29% / 2.81% |
| op=copy-ubyte w=256 h=128 layout=universal-negative | ldc | 30.866–37.013x | 0.990–1.042x | 23.275–26.030x | 1.018–1.031x | 10.73% / 1.00% |
| op=copy-float w=256 h=128 layout=universal-negative | dmd | 21.381–44.662x | 1.017–1.036x | 21.209–45.765x | 2.540–2.784x | 136.18% / 9.90% |
| op=copy-float w=256 h=128 layout=universal-negative | ldc | 32.929–34.334x | 0.976–0.993x | 26.127–26.660x | 0.860–0.881x | 2.70% / 2.28% |
| op=copy-Pod w=256 h=128 layout=universal-negative | dmd | 21.982–38.204x | 0.744–1.001x | 20.882–35.837x | 2.540–2.650x | 74.90% / 3.85% |
| op=copy-Pod w=256 h=128 layout=universal-negative | ldc | 32.134–33.967x | 0.989–1.021x | 23.269–24.609x | 0.969–0.974x | 6.27% / 0.48% |
| op=convert-ubyte-float w=256 h=128 layout=universal-negative | dmd | 65.864–130.927x | 0.949–1.011x | 68.861–134.145x | 14.758–15.261x | 100.74% / 3.05% |
| op=convert-ubyte-float w=256 h=128 layout=universal-negative | ldc | 77.799–79.315x | 0.995–1.021x | 60.329–62.420x | 5.179–5.221x | 4.90% / 1.38% |
| op=copy-ubyte w=256 h=128 layout=repeated-source | dmd | 22.540–51.678x | 0.999–1.309x | 2168.655–4179.469x | 2.417–2.700x | 122.73% / 18.52% |
| op=copy-ubyte w=256 h=128 layout=repeated-source | ldc | 34.818–37.125x | 1.014–1.026x | 1121.227–1130.762x | 3.286–3.667x | 8.81% / 9.52% |
| op=copy-float w=256 h=128 layout=repeated-source | dmd | 21.296–43.472x | 0.890–1.088x | 1585.676–2651.822x | 1.500–1.667x | 103.40% / 25.00% |
| op=copy-float w=256 h=128 layout=repeated-source | ldc | 31.383–38.707x | 0.939–1.058x | 701.914–784.889x | 1.600–1.750x | 18.62% / 12.50% |
| op=copy-Pod w=256 h=128 layout=repeated-source | dmd | 20.140–44.910x | 1.025–1.210x | 1007.964–2082.421x | 1.455–1.500x | 112.30% / 18.75% |
| op=copy-Pod w=256 h=128 layout=repeated-source | ldc | 32.176–34.016x | 0.966–1.017x | 479.420–532.021x | 1.567–1.667x | 7.71% / 6.38% |
| op=convert-ubyte-float w=256 h=128 layout=repeated-source | dmd | 101.721–214.882x | 1.005–1.037x | 1389.122–2914.085x | 6.242–6.455x | 114.15% / 3.40% |
| op=convert-ubyte-float w=256 h=128 layout=repeated-source | ldc | 131.940–141.012x | 1.021–1.049x | 2641.553–2701.111x | 1.161–1.310x | 6.59% / 8.33% |
| op=copy-ubyte w=256 h=128 layout=zero-source | dmd | 6.398–19.684x | 0.963–2.678x | 6.128–20.270x | 2.644–2.772x | 217.89% / 4.85% |
| op=copy-ubyte w=256 h=128 layout=zero-source | ldc | 9.001–9.714x | 0.904–0.964x | 6.206–6.582x | 1.007–1.028x | 7.76% / 1.61% |
| op=copy-float w=256 h=128 layout=zero-source | dmd | 6.334–6.572x | 0.329–1.035x | 6.411–6.635x | 2.510–2.587x | 6.33% / 2.97% |
| op=copy-float w=256 h=128 layout=zero-source | ldc | 8.345–8.651x | 0.968–0.984x | 6.904–7.096x | 0.854–0.867x | 4.35% / 1.53% |
| op=copy-Pod w=256 h=128 layout=zero-source | dmd | 6.465–7.106x | 0.517–1.003x | 6.088–6.426x | 2.554–2.735x | 10.91% / 7.19% |
| op=copy-Pod w=256 h=128 layout=zero-source | ldc | 8.471–8.915x | 0.953–0.969x | 6.151–6.488x | 0.949–0.961x | 4.55% / 0.98% |
| op=convert-ubyte-float w=256 h=128 layout=zero-source | dmd | 16.136–33.436x | 0.976–1.019x | 16.430–30.727x | 14.824–16.275x | 101.58% / 9.79% |
| op=convert-ubyte-float w=256 h=128 layout=zero-source | ldc | 22.578–25.071x | 0.982–1.054x | 17.524–19.592x | 5.196–5.261x | 10.74% / 1.83% |
| op=copy-ubyte w=2048 h=512 layout=contiguous | dmd | 0.982–1.093x | 1.007–1.085x | 0.962–1.093x | 0.669–0.809x | 12.92% / 28.23% |
| op=copy-ubyte w=2048 h=512 layout=contiguous | ldc | 0.996–1.045x | 1.016–1.032x | 0.996–1.012x | 0.786–0.841x | 2.82% / 1.61% |
| op=copy-float w=2048 h=512 layout=contiguous | dmd | 0.823–1.020x | 1.020–1.078x | 0.891–0.953x | 0.973–1.092x | 16.73% / 23.80% |
| op=copy-float w=2048 h=512 layout=contiguous | ldc | 0.982–1.224x | 0.971–1.139x | 0.935–1.194x | 1.018–1.121x | 67.51% / 42.12% |
| op=copy-Pod w=2048 h=512 layout=contiguous | dmd | 0.926–0.999x | 0.824–1.009x | 0.931–0.986x | 1.047–1.084x | 22.13% / 22.96% |
| op=copy-Pod w=2048 h=512 layout=contiguous | ldc | 0.976–1.079x | 0.941–1.045x | 0.992–1.031x | 1.113–1.130x | 26.49% / 31.49% |
| op=convert-ubyte-float w=2048 h=512 layout=contiguous | dmd | 0.978–1.030x | 7.250–16.513x | 7.373–15.469x | 8.141–9.563x | 126.32% / 17.11% |
| op=convert-ubyte-float w=2048 h=512 layout=contiguous | ldc | 0.947–0.992x | 19.654–41.015x | 17.934–36.129x | 1.100–2.251x | 9.87% / 105.63% |
| op=copy-ubyte w=2048 h=512 layout=padded | dmd | 11.019–12.748x | 0.911–1.131x | 2696.257–4122.947x | 0.971–1.109x | 59.35% / 15.90% |
| op=copy-ubyte w=2048 h=512 layout=padded | ldc | 17.935–18.739x | 1.042–1.069x | 986.283–1089.356x | 1.195–1.369x | 2.46% / 13.02% |
| op=copy-float w=2048 h=512 layout=padded | dmd | 10.831–11.371x | 1.047–1.122x | 534.435–616.698x | 1.185–1.331x | 3.28% / 11.73% |
| op=copy-float w=2048 h=512 layout=padded | ldc | 16.358–17.574x | 1.044–1.068x | 283.804–296.777x | 1.072–1.178x | 9.90% / 5.10% |
| op=copy-Pod w=2048 h=512 layout=padded | dmd | 10.656–11.055x | 1.039–1.086x | 196.291–225.580x | 1.035–1.053x | 2.82% / 14.13% |
| op=copy-Pod w=2048 h=512 layout=padded | ldc | 15.662–17.155x | 1.039–1.052x | 86.405–95.787x | 0.986–1.054x | 3.57% / 14.54% |
| op=convert-ubyte-float w=2048 h=512 layout=padded | dmd | 38.948–53.086x | 1.017–1.047x | 537.524–583.384x | 8.381–9.154x | 6.92% / 3.23% |
| op=convert-ubyte-float w=2048 h=512 layout=padded | ldc | 64.878–67.502x | 1.025–1.036x | 743.795–1671.381x | 1.021–2.279x | 2.12% / 122.84% |
| op=copy-ubyte w=2048 h=512 layout=negative-source | dmd | 11.000–11.457x | 1.073–1.120x | 1813.859–2473.726x | 1.398–1.553x | 93.05% / 70.00% |
| op=copy-ubyte w=2048 h=512 layout=negative-source | ldc | 17.737–18.263x | 1.017–1.073x | 470.052–956.678x | 1.378–2.011x | 1.26% / 106.10% |
| op=copy-float w=2048 h=512 layout=negative-source | dmd | 9.661–11.301x | 1.030–1.116x | 361.001–660.630x | 1.100–1.525x | 98.47% / 11.26% |
| op=copy-float w=2048 h=512 layout=negative-source | ldc | 16.106–16.295x | 1.059–1.068x | 176.060–207.341x | 1.191–1.299x | 8.30% / 25.91% |
| op=copy-Pod w=2048 h=512 layout=negative-source | dmd | 10.435–11.452x | 1.061–1.096x | 128.532–234.770x | 0.958–1.027x | 97.34% / 20.30% |
| op=copy-Pod w=2048 h=512 layout=negative-source | ldc | 14.689–15.724x | 1.040–1.055x | 53.558–64.908x | 0.992–1.112x | 2.35% / 18.41% |
| op=convert-ubyte-float w=2048 h=512 layout=negative-source | dmd | 46.876–49.078x | 1.010–1.013x | 513.685–530.205x | 5.308–6.639x | 4.67% / 4.74% |
| op=convert-ubyte-float w=2048 h=512 layout=negative-source | ldc | 65.031–66.147x | 1.000–1.029x | 319.419–362.671x | 3.437–3.552x | 2.74% / 16.44% |
| op=copy-ubyte w=2048 h=512 layout=negative-both | dmd | 10.769–11.406x | 1.086–1.107x | 1634.889–1805.819x | 1.503–1.811x | 5.09% / 16.07% |
| op=copy-ubyte w=2048 h=512 layout=negative-both | ldc | 17.215–18.857x | 1.040–1.064x | 1126.508–1205.904x | 1.109–1.252x | 2.33% / 7.61% |
| op=copy-float w=2048 h=512 layout=negative-both | dmd | 10.855–11.248x | 1.085–1.154x | 338.994–410.940x | 1.139–1.287x | 4.79% / 23.60% |
| op=copy-float w=2048 h=512 layout=negative-both | ldc | 15.815–16.734x | 1.027–1.073x | 147.734–198.336x | 1.069–1.397x | 0.76% / 35.27% |
| op=copy-Pod w=2048 h=512 layout=negative-both | dmd | 10.432–10.961x | 1.065–1.074x | 127.035–142.322x | 0.920–1.076x | 9.05% / 15.50% |
| op=copy-Pod w=2048 h=512 layout=negative-both | ldc | 15.043–15.804x | 1.044–1.058x | 58.442–64.671x | 0.977–1.056x | 2.06% / 12.35% |
| op=convert-ubyte-float w=2048 h=512 layout=negative-both | dmd | 48.960–53.279x | 1.005–1.023x | 514.604–538.652x | 4.741–5.825x | 7.96% / 4.74% |
| op=convert-ubyte-float w=2048 h=512 layout=negative-both | ldc | 64.972–66.367x | 1.024–1.050x | 323.807–365.440x | 3.135–3.427x | 8.84% / 19.77% |
| op=copy-ubyte w=2048 h=512 layout=universal | dmd | 10.600–11.428x | 0.978–1.025x | 10.732–11.551x | 2.674–2.755x | 8.44% / 1.66% |
| op=copy-ubyte w=2048 h=512 layout=universal | ldc | 17.751–18.429x | 0.958–0.971x | 12.272–12.693x | 0.997–1.042x | 4.65% / 2.50% |
| op=copy-float w=2048 h=512 layout=universal | dmd | 10.330–11.924x | 0.954–1.022x | 9.334–10.831x | 2.485–2.787x | 112.22% / 133.98% |
| op=copy-float w=2048 h=512 layout=universal | ldc | 16.348–16.615x | 0.972–1.009x | 13.218–13.474x | 0.836–0.867x | 4.90% / 2.91% |
| op=copy-Pod w=2048 h=512 layout=universal | dmd | 11.059–12.036x | 0.974–1.020x | 10.876–11.015x | 2.385–2.627x | 99.76% / 99.25% |
| op=copy-Pod w=2048 h=512 layout=universal | ldc | 15.915–16.924x | 0.982–0.997x | 11.709–12.145x | 0.968–0.996x | 9.92% / 5.97% |
| op=convert-ubyte-float w=2048 h=512 layout=universal | dmd | 26.221–29.955x | 0.953–1.033x | 27.866–29.824x | 13.413–27.718x | 99.53% / 107.21% |
| op=convert-ubyte-float w=2048 h=512 layout=universal | ldc | 37.852–39.069x | 1.010–1.012x | 28.974–30.793x | 4.547–4.923x | 1.55% / 7.92% |
| op=copy-ubyte w=2048 h=512 layout=universal-negative | dmd | 11.227–11.863x | 0.964–1.035x | 11.103–11.599x | 2.622–2.660x | 98.54% / 105.03% |
| op=copy-ubyte w=2048 h=512 layout=universal-negative | ldc | 17.743–18.115x | 0.973–0.985x | 12.228–13.012x | 1.007–1.025x | 8.14% / 1.79% |
| op=copy-float w=2048 h=512 layout=universal-negative | dmd | 10.471–10.920x | 0.956–1.034x | 10.546–11.971x | 2.445–2.523x | 16.37% / 8.09% |
| op=copy-float w=2048 h=512 layout=universal-negative | ldc | 15.737–16.504x | 0.969–1.015x | 13.147–13.610x | 0.857–0.883x | 1.33% / 3.87% |
| op=copy-Pod w=2048 h=512 layout=universal-negative | dmd | 10.775–10.870x | 0.957–1.043x | 10.686–10.790x | 2.434–2.599x | 10.01% / 9.88% |
| op=copy-Pod w=2048 h=512 layout=universal-negative | ldc | 15.902–16.499x | 0.968–0.988x | 11.316–11.932x | 0.963–1.043x | 3.67% / 5.17% |
| op=convert-ubyte-float w=2048 h=512 layout=universal-negative | dmd | 31.980–33.423x | 0.976–1.037x | 32.039–36.263x | 12.483–13.530x | 14.10% / 1.60% |
| op=convert-ubyte-float w=2048 h=512 layout=universal-negative | ldc | 38.264–39.404x | 1.000–1.026x | 30.415–31.190x | 4.344–4.762x | 1.89% / 4.49% |
| op=copy-ubyte w=2048 h=512 layout=repeated-source | dmd | 10.240–11.126x | 0.858–1.146x | 4783.691–5479.917x | 1.233–1.286x | 28.18% / 42.22% |
| op=copy-ubyte w=2048 h=512 layout=repeated-source | ldc | 18.017–18.726x | 1.015–1.055x | 2147.284–2261.505x | 1.489–1.515x | 4.80% / 0.50% |
| op=copy-float w=2048 h=512 layout=repeated-source | dmd | 10.322–11.305x | 0.912–1.165x | 1577.836–2822.645x | 1.045–1.051x | 95.44% / 9.25% |
| op=copy-float w=2048 h=512 layout=repeated-source | ldc | 16.886–17.834x | 1.061–1.080x | 677.731–728.431x | 1.074–1.094x | 5.99% / 2.36% |
| op=copy-Pod w=2048 h=512 layout=repeated-source | dmd | 10.889–10.974x | 1.054–1.129x | 470.118–665.788x | 0.980–1.252x | 91.84% / 170.37% |
| op=copy-Pod w=2048 h=512 layout=repeated-source | ldc | 16.121–17.008x | 1.037–1.059x | 225.392–306.796x | 0.878–1.424x | 6.63% / 45.14% |
| op=convert-ubyte-float w=2048 h=512 layout=repeated-source | dmd | 50.183–89.013x | 0.959–1.054x | 542.288–975.231x | 7.725–9.891x | 81.40% / 1.63% |
| op=convert-ubyte-float w=2048 h=512 layout=repeated-source | ldc | 65.596–67.797x | 1.013–1.034x | 738.307–1748.294x | 0.973–2.558x | 1.77% / 139.92% |
| op=copy-ubyte w=2048 h=512 layout=zero-source | dmd | 3.655–3.718x | 0.944–0.993x | 3.624–3.761x | 2.628–2.705x | 6.24% / 7.31% |
| op=copy-ubyte w=2048 h=512 layout=zero-source | ldc | 5.005–5.093x | 0.912–0.934x | 3.369–3.509x | 1.006–1.040x | 1.86% / 4.62% |
| op=copy-float w=2048 h=512 layout=zero-source | dmd | 3.574–3.692x | 0.993–1.014x | 3.531–3.554x | 2.480–2.587x | 2.72% / 2.66% |
| op=copy-float w=2048 h=512 layout=zero-source | ldc | 4.674–4.870x | 0.949–0.979x | 3.645–3.836x | 0.864–0.907x | 8.64% / 13.82% |
| op=copy-Pod w=2048 h=512 layout=zero-source | dmd | 3.604–3.757x | 1.000–1.021x | 3.566–3.613x | 2.331–2.571x | 6.39% / 5.01% |
| op=copy-Pod w=2048 h=512 layout=zero-source | ldc | 4.645–4.810x | 0.924–0.936x | 3.367–3.426x | 0.879–0.948x | 3.46% / 3.79% |
| op=convert-ubyte-float w=2048 h=512 layout=zero-source | dmd | 8.404–8.544x | 0.969–1.006x | 8.405–8.659x | 13.341–13.670x | 2.85% / 0.54% |
| op=convert-ubyte-float w=2048 h=512 layout=zero-source | ldc | 11.801–12.836x | 1.046–1.085x | 9.236–9.879x | 4.594–4.841x | 9.87% / 9.65% |
