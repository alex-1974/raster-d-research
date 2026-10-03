# Full public copy/conversion candidates — xps evidence

Production: `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`. All six processes pass 96 timed cases, 32 extra semantic cases and public controls for all four public paths. Source/output hashes match across compilers/processes.

Bounds, Execute and Combined are complete pinned public consumers, changing only conservative relation rejection and/or unit-sample-stride row execution (plus already-approved flat conversion). Original Universal execution, errors, injectivity, overlap and arithmetic-failure fallback remain. C++ is execution-only and omits validation while adding a separate C ABI call; it is not a complete-library comparison. No reassociation/precision change, compiler switch, explicit SIMD or threading.

Fifteen cyclic rounds rotate five paths through every order position three times. Two warmups; reset and full backing checks are outside each timer. All large samples are positive; tiny zero medians retain data and omit ratios. VM is diagnostic, XPS is required for promotion; AArch64 unqualified.

| Case | Compiler | Public/Bounds | Public/Execute | Public/Combined | Combined/C++ | Public/Combined process spread |
| --- | --- | --- | --- | --- | --- | --- |
| op=copy-ubyte w=31 h=17 layout=contiguous | dmd | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | below clock resolution | 0.00% / 0.00% |
| op=copy-ubyte w=31 h=17 layout=contiguous | ldc | below clock resolution | below clock resolution | below clock resolution | below clock resolution | below clock resolution / below clock resolution |
| op=copy-float w=31 h=17 layout=contiguous | dmd | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 0.00% / 0.00% |
| op=copy-float w=31 h=17 layout=contiguous | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 0.00% / 0.00% |
| op=copy-Pod w=31 h=17 layout=contiguous | dmd | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 2.000–2.000x | 0.00% / 0.00% |
| op=copy-Pod w=31 h=17 layout=contiguous | ldc | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 0.00% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=contiguous | dmd | 1.000–1.000x | 4.600–4.600x | 3.833–3.833x | 6.000–6.000x | 0.00% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=contiguous | ldc | 1.000–1.056x | 9.000–9.500x | 9.500–19.000x | 1.000–2.000x | 5.56% / 100.00% |
| op=copy-ubyte w=31 h=17 layout=padded | dmd | 19.132–19.273x | 1.054–1.054x | 325.250–424.000x | below clock resolution | 4.58% / 33.33% |
| op=copy-ubyte w=31 h=17 layout=padded | ldc | 26.056–30.857x | 0.994–1.031x | 117.750–156.333x | below clock resolution | 9.03% / 33.33% |
| op=copy-float w=31 h=17 layout=padded | dmd | 19.952–20.281x | 1.048–1.050x | 309.250–324.500x | 4.000–4.000x | 4.93% / 0.00% |
| op=copy-float w=31 h=17 layout=padded | ldc | 38.833–43.200x | 1.004–1.024x | 93.200–156.000x | 3.000–5.000x | 8.33% / 66.67% |
| op=copy-Pod w=31 h=17 layout=padded | dmd | 20.571–21.032x | 1.047–1.069x | 247.200–265.000x | 5.000–5.000x | 7.20% / 0.00% |
| op=copy-Pod w=31 h=17 layout=padded | ldc | 27.000–33.308x | 1.020–1.030x | 69.429–144.333x | 3.000–7.000x | 12.24% / 133.33% |
| op=convert-ubyte-float w=31 h=17 layout=padded | dmd | 104.297–108.934x | 1.009–1.053x | 1107.500–1156.000x | 6.000–6.000x | 4.38% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=padded | ldc | 109.950–131.933x | 1.006–1.013x | 314.143–1067.000x | 2.000–3.500x | 11.12% / 250.00% |
| op=copy-ubyte w=31 h=17 layout=negative-source | dmd | 19.044–19.328x | 1.052–1.053x | 323.750–431.667x | below clock resolution | 0.54% / 33.33% |
| op=copy-ubyte w=31 h=17 layout=negative-source | ldc | 28.625–30.857x | 1.013–1.024x | 144.000–152.667x | below clock resolution | 6.02% / 0.00% |
| op=copy-float w=31 h=17 layout=negative-source | dmd | 19.831–20.172x | 1.048–1.049x | 322.250–330.750x | 4.000–4.000x | 2.64% / 0.00% |
| op=copy-float w=31 h=17 layout=negative-source | ldc | 43.182–45.800x | 1.019–1.024x | 95.000–152.667x | 3.000–5.000x | 9.70% / 66.67% |
| op=copy-Pod w=31 h=17 layout=negative-source | dmd | 20.492–20.641x | 1.047–1.066x | 258.200–264.200x | 5.000–5.000x | 2.32% / 0.00% |
| op=copy-Pod w=31 h=17 layout=negative-source | ldc | 29.125–33.308x | 1.015–1.024x | 77.667–144.333x | 3.000–4.000x | 7.62% / 100.00% |
| op=convert-ubyte-float w=31 h=17 layout=negative-source | dmd | 104.030–104.250x | 1.009–1.011x | 1112.000–1144.333x | 3.000–6.000x | 2.91% / 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=negative-source | ldc | 90.750–131.733x | 1.005–1.014x | 155.571–658.667x | 3.000–4.667x | 10.22% / 366.67% |
| op=copy-ubyte w=31 h=17 layout=negative-both | dmd | 19.235–19.529x | 1.054–1.073x | 327.000–341.750x | below clock resolution | 4.51% / 0.00% |
| op=copy-ubyte w=31 h=17 layout=negative-both | ldc | 28.938–30.857x | 1.022–1.026x | 144.000–154.333x | below clock resolution | 7.18% / 0.00% |
| op=copy-float w=31 h=17 layout=negative-both | dmd | 20.015–20.281x | 1.046–1.048x | 324.500–332.500x | 4.000–4.000x | 2.47% / 0.00% |
| op=copy-float w=31 h=17 layout=negative-both | ldc | 33.438–45.600x | 1.022–1.064x | 107.000–152.000x | 3.000–5.000x | 23.84% / 66.67% |
| op=copy-Pod w=31 h=17 layout=negative-both | dmd | 20.603–20.619x | 1.027–1.047x | 259.600–259.800x | 5.000–5.000x | 0.08% / 0.00% |
| op=copy-Pod w=31 h=17 layout=negative-both | ldc | 29.312–33.308x | 1.009–1.026x | 93.800–144.333x | 3.000–5.000x | 8.31% / 66.67% |
| op=convert-ubyte-float w=31 h=17 layout=negative-both | dmd | 103.812–106.323x | 1.008–1.031x | 987.286–1152.667x | 6.000–7.000x | 4.09% / 16.67% |
| op=convert-ubyte-float w=31 h=17 layout=negative-both | ldc | 91.875–132.133x | 0.998–1.029x | 275.625–660.667x | 2.000–3.000x | 11.25% / 166.67% |
| op=copy-ubyte w=31 h=17 layout=universal | dmd | 19.147–19.377x | 0.973–1.002x | 19.100–19.758x | 4.400–4.667x | 2.69% / 6.06% |
| op=copy-ubyte w=31 h=17 layout=universal | ldc | 29.250–30.929x | 0.973–0.995x | 19.500–19.826x | 1.438–1.500x | 8.08% / 9.09% |
| op=copy-float w=31 h=17 layout=universal | dmd | 20.106–20.250x | 0.996–1.001x | 19.806–19.938x | 5.417–5.583x | 2.39% / 3.08% |
| op=copy-float w=31 h=17 layout=universal | ldc | 31.733–45.600x | 0.932–0.991x | 16.414–25.333x | 1.500–2.071x | 10.19% / 61.11% |
| op=copy-Pod w=31 h=17 layout=universal | dmd | 20.266–20.540x | 1.000–1.002x | 20.266–20.540x | 5.250–5.417x | 2.70% / 3.17% |
| op=copy-Pod w=31 h=17 layout=universal | ldc | 29.375–33.308x | 0.992–0.998x | 18.077–19.913x | 1.833–2.167x | 8.55% / 18.18% |
| op=convert-ubyte-float w=31 h=17 layout=universal | dmd | 60.967–61.723x | 0.999–1.005x | 60.788–61.203x | 20.333–22.000x | 7.88% / 8.20% |
| op=convert-ubyte-float w=31 h=17 layout=universal | ldc | 60.500–74.267x | 0.976–1.021x | 60.500–69.625x | 5.333–6.667x | 8.89% / 25.00% |
| op=copy-ubyte w=31 h=17 layout=universal-negative | dmd | 18.914–19.015x | 1.000–1.002x | 18.914–19.299x | 4.467–4.667x | 7.38% / 7.69% |
| op=copy-ubyte w=31 h=17 layout=universal-negative | ldc | 25.778–30.200x | 0.978–1.007x | 17.846–19.182x | 1.467–1.625x | 9.95% / 18.18% |
| op=copy-float w=31 h=17 layout=universal-negative | dmd | 19.657–19.790x | 0.998–1.002x | 19.368–19.790x | 5.417–5.667x | 7.33% / 9.68% |
| op=copy-float w=31 h=17 layout=universal-negative | ldc | 24.100–44.500x | 0.988–0.998x | 20.083–24.765x | 1.412–1.500x | 14.49% / 41.18% |
| op=copy-Pod w=31 h=17 layout=universal-negative | dmd | 20.094–20.433x | 0.999–1.002x | 20.094–20.246x | 5.333–5.545x | 7.34% / 6.56% |
| op=copy-Pod w=31 h=17 layout=universal-negative | ldc | 29.062–31.786x | 0.991–0.998x | 17.885–19.348x | 1.857–1.917x | 6.65% / 13.04% |
| op=convert-ubyte-float w=31 h=17 layout=universal-negative | dmd | 67.879–68.281x | 0.999–1.000x | 67.879–68.281x | 20.333–22.000x | 7.85% / 8.20% |
| op=convert-ubyte-float w=31 h=17 layout=universal-negative | ldc | 63.571–75.562x | 0.998–1.018x | 60.682–75.562x | 5.333–7.333x | 10.42% / 37.50% |
| op=copy-ubyte w=31 h=17 layout=repeated-source | dmd | 19.031–19.261x | 1.051–1.054x | 412.333–443.000x | below clock resolution | 7.44% / 0.00% |
| op=copy-ubyte w=31 h=17 layout=repeated-source | ldc | 27.471–30.857x | 1.009–1.024x | 116.000–216.000x | below clock resolution | 8.10% / 100.00% |
| op=copy-float w=31 h=17 layout=repeated-source | dmd | 19.970–20.123x | 1.048–1.065x | 306.500–329.500x | 4.000–4.000x | 7.50% / 0.00% |
| op=copy-float w=31 h=17 layout=repeated-source | ldc | 36.077–41.900x | 1.018–1.024x | 52.111–139.667x | 3.000–9.000x | 11.93% / 200.00% |
| op=copy-Pod w=31 h=17 layout=repeated-source | dmd | 20.292–20.450x | 1.047–1.049x | 245.400–263.800x | 5.000–5.000x | 7.50% / 0.00% |
| op=copy-Pod w=31 h=17 layout=repeated-source | ldc | 28.500–32.231x | 1.018–1.043x | 77.333–139.667x | 3.000–6.000x | 10.74% / 100.00% |
| op=convert-ubyte-float w=31 h=17 layout=repeated-source | dmd | 103.788–104.508x | 1.008–1.012x | 1141.667–1275.000x | 5.000–6.000x | 7.69% / 20.00% |
| op=convert-ubyte-float w=31 h=17 layout=repeated-source | ldc | 104.762–131.933x | 1.005–1.043x | 440.000–1039.000x | 2.000–2.500x | 11.17% / 150.00% |
| op=copy-ubyte w=31 h=17 layout=zero-source | dmd | 4.797–4.986x | 0.997–1.045x | 4.868–4.986x | 4.375–4.533x | 12.94% / 11.11% |
| op=copy-ubyte w=31 h=17 layout=zero-source | ldc | 7.267–7.429x | 0.973–0.981x | 4.727–4.783x | 1.533–1.571x | 5.77% / 4.55% |
| op=copy-float w=31 h=17 layout=zero-source | dmd | 5.606–5.639x | 1.000–1.005x | 5.522–5.548x | 5.583–5.636x | 7.56% / 8.06% |
| op=copy-float w=31 h=17 layout=zero-source | ldc | 10.000–11.556x | 0.963–0.965x | 5.789–6.118x | 1.417–1.583x | 6.73% / 11.76% |
| op=copy-Pod w=31 h=17 layout=zero-source | dmd | 5.692–5.750x | 1.003–1.005x | 5.692–5.750x | 5.417–5.455x | 7.54% / 8.33% |
| op=copy-Pod w=31 h=17 layout=zero-source | ldc | 7.400–8.143x | 0.981–0.983x | 4.609–4.826x | 1.917–2.000x | 7.55% / 4.35% |
| op=convert-ubyte-float w=31 h=17 layout=zero-source | dmd | 16.902–17.212x | 0.999–1.023x | 16.902–17.212x | 20.333–22.000x | 10.18% / 8.20% |
| op=convert-ubyte-float w=31 h=17 layout=zero-source | ldc | 16.381–19.267x | 0.994–1.027x | 13.231–18.062x | 5.333–8.667x | 19.03% / 62.50% |
| op=copy-ubyte w=256 h=128 layout=contiguous | dmd | 1.000–1.000x | 1.000–1.000x | 1.000–1.000x | 0.727–0.800x | 0.00% / 0.00% |
| op=copy-ubyte w=256 h=128 layout=contiguous | ldc | 0.875–1.000x | 0.700–1.000x | 0.923–1.000x | 0.700–1.167x | 200.00% / 200.00% |
| op=copy-float w=256 h=128 layout=contiguous | dmd | 1.000–1.000x | 1.000–1.029x | 1.000–1.000x | 0.795–0.846x | 9.09% / 9.09% |
| op=copy-float w=256 h=128 layout=contiguous | ldc | 0.885–1.000x | 1.000–1.022x | 0.971–1.000x | 0.795–0.868x | 48.39% / 48.39% |
| op=copy-Pod w=256 h=128 layout=contiguous | dmd | 0.976–1.023x | 1.000–1.084x | 0.890–1.011x | 0.907–0.938x | 11.11% / 4.55% |
| op=copy-Pod w=256 h=128 layout=contiguous | ldc | 0.842–1.098x | 1.000–1.273x | 0.560–1.258x | 0.765–1.155x | 105.33% / 266.67% |
| op=convert-ubyte-float w=256 h=128 layout=contiguous | dmd | 1.000–1.001x | 5.787–5.807x | 4.355–4.364x | 7.524–7.535x | 2.39% / 2.53% |
| op=convert-ubyte-float w=256 h=128 layout=contiguous | ldc | 0.961–0.998x | 20.661–26.610x | 17.530–26.610x | 0.880–0.977x | 6.05% / 60.98% |
| op=copy-ubyte w=256 h=128 layout=padded | dmd | 18.763–19.142x | 1.046–1.066x | 3390.136–3628.150x | 1.667–1.692x | 3.59% / 10.00% |
| op=copy-ubyte w=256 h=128 layout=padded | ldc | 28.915–29.630x | 1.031–1.051x | 996.808–1093.739x | 1.917–2.077x | 7.89% / 17.39% |
| op=copy-float w=256 h=128 layout=padded | dmd | 19.537–19.831x | 1.037–1.044x | 1404.385–1551.354x | 1.021–1.061x | 1.97% / 8.33% |
| op=copy-float w=256 h=128 layout=padded | ldc | 43.255–44.754x | 1.016–1.028x | 422.635–472.481x | 1.268–1.312x | 8.37% / 21.15% |
| op=copy-Pod w=256 h=128 layout=padded | dmd | 19.829–20.341x | 1.042–1.067x | 710.212–740.697x | 0.980–1.020x | 1.05% / 5.05% |
| op=copy-Pod w=256 h=128 layout=padded | ldc | 31.427–31.599x | 1.027–1.039x | 165.327–223.491x | 1.068–1.260x | 10.96% / 50.00% |
| op=convert-ubyte-float w=256 h=128 layout=padded | dmd | 101.534–103.130x | 0.992–1.022x | 1773.592–1829.302x | 4.844–4.955x | 3.87% / 6.34% |
| op=convert-ubyte-float w=256 h=128 layout=padded | ldc | 125.405–129.238x | 0.987–1.006x | 1625.162–2650.614x | 1.023–1.176x | 11.48% / 81.82% |
| op=copy-ubyte w=256 h=128 layout=negative-source | dmd | 18.776–18.832x | 1.052–1.056x | 3207.435–3780.579x | 1.583–1.769x | 3.21% / 21.05% |
| op=copy-ubyte w=256 h=128 layout=negative-source | ldc | 29.575–30.689x | 1.029–1.050x | 815.059–1103.261x | 2.091–2.462x | 9.21% / 47.83% |
| op=copy-float w=256 h=128 layout=negative-source | dmd | 19.415–19.658x | 1.044–1.061x | 1373.000–1399.434x | 1.082–1.104x | 3.31% / 1.92% |
| op=copy-float w=256 h=128 layout=negative-source | ldc | 39.731–43.400x | 1.029–1.036x | 288.681–449.857x | 1.273–1.958x | 7.72% / 67.86% |
| op=copy-Pod w=256 h=128 layout=negative-source | dmd | 19.832–20.102x | 1.035–1.053x | 551.610–717.559x | 0.990–1.248x | 4.93% / 36.00% |
| op=copy-Pod w=256 h=128 layout=negative-source | ldc | 30.919–31.937x | 1.018–1.027x | 156.594–215.956x | 1.107–1.366x | 8.13% / 49.12% |
| op=convert-ubyte-float w=256 h=128 layout=negative-source | dmd | 101.382–102.306x | 1.007–1.014x | 1719.535–1834.421x | 4.698–5.000x | 6.73% / 13.86% |
| op=convert-ubyte-float w=256 h=128 layout=negative-source | ldc | 125.362–132.961x | 0.999–1.066x | 1003.821–1056.464x | 2.389–2.674x | 16.47% / 17.27% |
| op=copy-ubyte w=256 h=128 layout=negative-both | dmd | 18.682–19.209x | 1.058–1.059x | 2426.969–3816.474x | 1.583–2.133x | 7.10% / 68.42% |
| op=copy-ubyte w=256 h=128 layout=negative-both | ldc | 28.782–29.548x | 1.010–1.031x | 775.000–1117.273x | 1.944–2.600x | 10.35% / 59.09% |
| op=copy-float w=256 h=128 layout=negative-both | dmd | 19.432–19.642x | 1.053–1.064x | 819.811–1486.796x | 1.021–1.827x | 7.12% / 93.88% |
| op=copy-float w=256 h=128 layout=negative-both | ldc | 42.342–44.097x | 1.024–1.063x | 260.383–480.400x | 1.282–2.058x | 15.99% / 114.00% |
| op=copy-Pod w=256 h=128 layout=negative-both | dmd | 20.345–20.904x | 1.051–1.077x | 434.893–767.117x | 1.011–1.447x | 11.67% / 89.36% |
| op=copy-Pod w=256 h=128 layout=negative-both | ldc | 30.650–31.981x | 1.003–1.032x | 158.870–244.535x | 1.110–1.156x | 8.71% / 67.33% |
| op=convert-ubyte-float w=256 h=128 layout=negative-both | dmd | 101.977–104.301x | 0.992–1.024x | 1778.943–1822.228x | 4.791–4.872x | 9.31% / 11.17% |
| op=convert-ubyte-float w=256 h=128 layout=negative-both | ldc | 125.910–127.456x | 1.004–1.015x | 980.946–1051.523x | 2.581–2.708x | 9.26% / 17.12% |
| op=copy-ubyte w=256 h=128 layout=universal | dmd | 18.575–19.480x | 0.975–1.004x | 18.469–19.373x | 4.516–4.696x | 6.18% / 1.22% |
| op=copy-ubyte w=256 h=128 layout=universal | ldc | 28.750–29.023x | 0.980–0.994x | 18.721–18.880x | 1.541–1.548x | 7.70% / 7.54% |
| op=copy-float w=256 h=128 layout=universal | dmd | 19.397–19.852x | 0.983–1.012x | 19.164–19.335x | 6.037–6.131x | 3.86% / 3.12% |
| op=copy-float w=256 h=128 layout=universal | ldc | 42.241–44.866x | 0.984–1.018x | 23.253–24.491x | 1.497–1.532x | 10.86% / 12.80% |
| op=copy-Pod w=256 h=128 layout=universal | dmd | 20.050–20.595x | 1.000–1.019x | 20.102–20.176x | 5.829–5.885x | 6.60% / 6.94% |
| op=copy-Pod w=256 h=128 layout=universal | ldc | 28.308–30.821x | 0.991–0.995x | 17.981–18.368x | 1.826–1.896x | 9.94% / 11.27% |
| op=convert-ubyte-float w=256 h=128 layout=universal | dmd | 59.729–60.361x | 0.991–1.003x | 59.740–60.314x | 19.793–20.317x | 1.46% / 2.43% |
| op=convert-ubyte-float w=256 h=128 layout=universal | ldc | 70.142–72.077x | 0.980–1.005x | 66.706–68.605x | 5.351–5.439x | 8.93% / 5.92% |
| op=copy-ubyte w=256 h=128 layout=universal-negative | dmd | 18.914–19.024x | 1.000–1.013x | 18.681–18.803x | 4.543–4.692x | 0.43% / 1.08% |
| op=copy-ubyte w=256 h=128 layout=universal-negative | ldc | 28.261–28.798x | 0.979–1.016x | 18.356–18.706x | 1.540–1.543x | 5.78% / 7.40% |
| op=copy-float w=256 h=128 layout=universal-negative | dmd | 19.297–19.843x | 0.985–1.012x | 18.923–19.681x | 3.594–6.127x | 14.26% / 10.05% |
| op=copy-float w=256 h=128 layout=universal-negative | ldc | 41.519–42.950x | 0.973–1.006x | 22.711–23.516x | 1.513–1.529x | 8.66% / 4.94% |
| op=copy-Pod w=256 h=128 layout=universal-negative | dmd | 19.705–20.292x | 0.993–1.014x | 19.768–19.985x | 5.239–5.787x | 1.42% / 2.09% |
| op=copy-Pod w=256 h=128 layout=universal-negative | ldc | 30.159–30.633x | 0.992–0.994x | 18.065–18.256x | 1.839–1.901x | 5.78% / 5.69% |
| op=convert-ubyte-float w=256 h=128 layout=universal-negative | dmd | 65.482–66.100x | 0.999–1.000x | 64.984–65.844x | 20.316–20.725x | 3.85% / 5.22% |
| op=convert-ubyte-float w=256 h=128 layout=universal-negative | ldc | 72.135–74.805x | 0.996–0.999x | 68.122–68.612x | 5.408–5.583x | 7.73% / 6.97% |
| op=copy-ubyte w=256 h=128 layout=repeated-source | dmd | 18.832–19.102x | 1.058–1.060x | 2989.154–3855.684x | 1.462–1.857x | 6.09% / 36.84% |
| op=copy-ubyte w=256 h=128 layout=repeated-source | ldc | 28.258–28.906x | 1.028–1.044x | 657.614–1190.550x | 2.444–3.385x | 21.52% / 120.00% |
| op=copy-float w=256 h=128 layout=repeated-source | dmd | 19.293–19.682x | 1.025–1.059x | 1216.697–1732.250x | 0.880–1.245x | 5.36% / 50.00% |
| op=copy-float w=256 h=128 layout=repeated-source | ldc | 40.012–43.382x | 0.958–1.045x | 400.118–610.821x | 1.500–1.700x | 14.21% / 74.36% |
| op=copy-Pod w=256 h=128 layout=repeated-source | dmd | 20.158–20.524x | 1.034–1.077x | 1018.000–1104.824x | 0.739–0.825x | 8.40% / 17.65% |
| op=copy-Pod w=256 h=128 layout=repeated-source | ldc | 30.674–31.367x | 1.001–1.028x | 287.473–314.608x | 1.194–1.338x | 12.37% / 22.97% |
| op=convert-ubyte-float w=256 h=128 layout=repeated-source | dmd | 101.332–105.863x | 1.004–1.013x | 1764.873–1799.204x | 5.182–5.250x | 1.81% / 2.67% |
| op=convert-ubyte-float w=256 h=128 layout=repeated-source | ldc | 120.763–124.613x | 1.002–1.022x | 2451.740–2810.750x | 1.000–1.136x | 9.03% / 25.00% |
| op=copy-ubyte w=256 h=128 layout=zero-source | dmd | 5.246–5.919x | 0.987–1.120x | 5.184–5.850x | 4.603–5.074x | 30.22% / 15.90% |
| op=copy-ubyte w=256 h=128 layout=zero-source | ldc | 6.965–6.985x | 0.972–0.978x | 4.526–4.554x | 1.531–1.542x | 5.42% / 4.97% |
| op=copy-float w=256 h=128 layout=zero-source | dmd | 5.343–5.638x | 0.947–1.014x | 5.275–5.464x | 6.095–6.280x | 9.59% / 8.68% |
| op=copy-float w=256 h=128 layout=zero-source | ldc | 10.509–10.607x | 0.951–0.957x | 5.693–5.712x | 1.499–1.514x | 5.62% / 5.96% |
| op=copy-Pod w=256 h=128 layout=zero-source | dmd | 5.489–5.720x | 0.946–1.026x | 5.520–5.642x | 5.859–5.915x | 5.18% / 2.91% |
| op=copy-Pod w=256 h=128 layout=zero-source | ldc | 7.616–7.707x | 0.971–0.983x | 4.526–4.583x | 1.891–1.894x | 6.27% / 4.95% |
| op=convert-ubyte-float w=256 h=128 layout=zero-source | dmd | 16.628–16.924x | 1.001–1.018x | 16.086–16.920x | 20.377–21.173x | 2.88% / 7.17% |
| op=convert-ubyte-float w=256 h=128 layout=zero-source | ldc | 17.717–18.150x | 0.951–0.997x | 16.887–17.275x | 5.378–5.420x | 4.93% / 7.34% |
| op=copy-ubyte w=2048 h=512 layout=contiguous | dmd | 0.852–0.974x | 0.533–1.123x | 0.651–1.123x | 0.826–1.304x | 99.55% / 244.36% |
| op=copy-ubyte w=2048 h=512 layout=contiguous | ldc | 0.928–1.058x | 0.967–1.011x | 0.994–1.100x | 0.775–0.842x | 37.36% / 51.96% |
| op=copy-float w=2048 h=512 layout=contiguous | dmd | 0.941–1.311x | 0.901–1.479x | 0.797–1.077x | 0.756–1.144x | 39.01% / 13.74% |
| op=copy-float w=2048 h=512 layout=contiguous | ldc | 0.870–1.324x | 0.998–1.531x | 1.025–1.406x | 0.802–1.003x | 42.09% / 19.55% |
| op=copy-Pod w=2048 h=512 layout=contiguous | dmd | 0.856–1.101x | 0.876–0.996x | 0.689–1.025x | 0.787–1.508x | 25.11% / 81.48% |
| op=copy-Pod w=2048 h=512 layout=contiguous | ldc | 0.971–1.001x | 0.947–1.006x | 0.996–1.013x | 0.746–0.949x | 11.50% / 10.04% |
| op=convert-ubyte-float w=2048 h=512 layout=contiguous | dmd | 0.999–1.089x | 5.726–6.151x | 4.374–4.776x | 2.055–6.721x | 22.36% / 14.71% |
| op=convert-ubyte-float w=2048 h=512 layout=contiguous | ldc | 0.945–1.012x | 18.150–22.327x | 20.210–23.135x | 0.938–0.998x | 3.44% / 14.22% |
| op=copy-ubyte w=2048 h=512 layout=padded | dmd | 9.913–10.345x | 1.093–1.114x | 1590.642–2892.533x | 0.959–1.158x | 61.30% / 37.04% |
| op=copy-ubyte w=2048 h=512 layout=padded | ldc | 14.488–15.050x | 1.059–1.063x | 520.082–934.892x | 1.026–1.643x | 7.56% / 93.35% |
| op=copy-float w=2048 h=512 layout=padded | dmd | 9.900–10.215x | 1.089–1.117x | 194.714–533.617x | 0.878–1.049x | 5.48% / 188.86% |
| op=copy-float w=2048 h=512 layout=padded | ldc | 19.947–21.845x | 1.046–1.063x | 109.467–134.640x | 1.052–1.164x | 3.91% / 27.61% |
| op=copy-Pod w=2048 h=512 layout=padded | dmd | 10.311–10.740x | 1.086–1.110x | 128.592–159.125x | 1.110–1.161x | 7.78% / 29.51% |
| op=copy-Pod w=2048 h=512 layout=padded | ldc | 14.982–15.182x | 1.044–1.068x | 46.604–63.420x | 0.998–1.016x | 14.31% / 55.56% |
| op=convert-ubyte-float w=2048 h=512 layout=padded | dmd | 50.593–51.684x | 1.021–1.023x | 975.357–980.202x | 3.953–4.065x | 3.36% / 3.36% |
| op=convert-ubyte-float w=2048 h=512 layout=padded | ldc | 62.394–65.162x | 1.010–1.049x | 891.907–1214.341x | 1.007–1.209x | 6.54% / 45.06% |
| op=copy-ubyte w=2048 h=512 layout=negative-source | dmd | 9.770–10.017x | 1.120–1.143x | 2210.466–2424.429x | 1.207–1.312x | 7.03% / 17.39% |
| op=copy-ubyte w=2048 h=512 layout=negative-source | ldc | 14.852–15.371x | 1.054–1.074x | 751.755–935.174x | 1.128–1.334x | 4.30% / 29.19% |
| op=copy-float w=2048 h=512 layout=negative-source | dmd | 9.966–10.164x | 1.092–1.101x | 335.520–515.730x | 0.960–1.114x | 3.31% / 58.80% |
| op=copy-float w=2048 h=512 layout=negative-source | ldc | 21.108–22.054x | 1.055–1.060x | 110.437–172.369x | 1.083–1.244x | 5.84% / 65.19% |
| op=copy-Pod w=2048 h=512 layout=negative-source | dmd | 10.347–10.427x | 1.088–1.108x | 120.649–126.376x | 1.161–1.196x | 1.71% / 6.08% |
| op=copy-Pod w=2048 h=512 layout=negative-source | ldc | 14.850–15.498x | 1.056–1.069x | 46.975–62.765x | 0.928–1.031x | 3.18% / 36.14% |
| op=convert-ubyte-float w=2048 h=512 layout=negative-source | dmd | 50.635–51.581x | 1.009–1.015x | 909.389–939.728x | 2.665–2.924x | 2.47% / 3.47% |
| op=convert-ubyte-float w=2048 h=512 layout=negative-source | ldc | 61.950–64.670x | 1.003–1.022x | 466.244–503.264x | 1.808–2.175x | 3.27% / 10.26% |
| op=copy-ubyte w=2048 h=512 layout=negative-both | dmd | 9.868–9.882x | 1.106–1.117x | 1594.498–1776.390x | 1.111–1.152x | 1.95% / 12.65% |
| op=copy-ubyte w=2048 h=512 layout=negative-both | ldc | 14.679–15.099x | 1.031–1.065x | 429.375–665.134x | 1.118–1.416x | 2.49% / 58.77% |
| op=copy-float w=2048 h=512 layout=negative-both | dmd | 9.875–10.214x | 1.100–1.108x | 336.406–411.809x | 0.813–0.939x | 5.29% / 25.95% |
| op=copy-float w=2048 h=512 layout=negative-both | ldc | 20.851–22.141x | 1.047–1.061x | 90.070–148.540x | 0.857–1.186x | 4.10% / 68.11% |
| op=copy-Pod w=2048 h=512 layout=negative-both | dmd | 9.947–10.566x | 1.094–1.111x | 135.424–151.052x | 1.068–1.245x | 5.19% / 12.20% |
| op=copy-Pod w=2048 h=512 layout=negative-both | ldc | 14.804–15.424x | 1.040–1.058x | 48.344–51.057x | 0.991–1.072x | 8.61% / 13.30% |
| op=convert-ubyte-float w=2048 h=512 layout=negative-both | dmd | 51.355–51.856x | 1.006–1.034x | 920.221–929.541x | 2.918–3.516x | 8.07% / 7.75% |
| op=convert-ubyte-float w=2048 h=512 layout=negative-both | ldc | 60.606–61.587x | 0.985–1.029x | 463.266–475.638x | 1.542–1.848x | 5.29% / 8.10% |
| op=copy-ubyte w=2048 h=512 layout=universal | dmd | 9.805–9.914x | 0.993–1.004x | 9.788–10.114x | 4.404–4.669x | 1.83% / 2.38% |
| op=copy-ubyte w=2048 h=512 layout=universal | ldc | 14.776–14.887x | 0.981–0.991x | 9.608–9.664x | 1.474–1.511x | 4.45% / 4.69% |
| op=copy-float w=2048 h=512 layout=universal | dmd | 9.847–10.068x | 0.978–1.008x | 9.798–9.950x | 5.579–5.711x | 1.81% / 2.07% |
| op=copy-float w=2048 h=512 layout=universal | ldc | 19.765–20.378x | 0.971–0.983x | 11.217–11.410x | 1.471–1.538x | 9.24% / 7.40% |
| op=copy-Pod w=2048 h=512 layout=universal | dmd | 10.119–10.447x | 0.991–1.010x | 10.139–10.422x | 4.683–4.971x | 7.19% / 7.97% |
| op=copy-Pod w=2048 h=512 layout=universal | ldc | 13.498–14.294x | 0.974–0.997x | 8.790–8.890x | 1.613–1.763x | 10.74% / 11.33% |
| op=convert-ubyte-float w=2048 h=512 layout=universal | dmd | 29.465–29.919x | 0.964–1.000x | 28.884–29.997x | 17.239–19.625x | 6.34% / 6.60% |
| op=convert-ubyte-float w=2048 h=512 layout=universal | ldc | 34.651–35.226x | 0.987–0.999x | 32.579–33.305x | 4.725–5.210x | 8.41% / 10.13% |
| op=copy-ubyte w=2048 h=512 layout=universal-negative | dmd | 9.687–9.781x | 0.996–1.014x | 9.706–10.039x | 4.341–4.670x | 7.03% / 9.42% |
| op=copy-ubyte w=2048 h=512 layout=universal-negative | ldc | 14.538–14.598x | 0.986–0.994x | 9.350–9.387x | 1.496–1.548x | 9.77% / 10.21% |
| op=copy-float w=2048 h=512 layout=universal-negative | dmd | 9.790–10.141x | 0.992–1.007x | 9.717–9.906x | 5.400–5.814x | 7.00% / 8.18% |
| op=copy-float w=2048 h=512 layout=universal-negative | ldc | 19.863–19.917x | 0.977–0.990x | 11.371–11.471x | 1.458–1.514x | 8.36% / 7.41% |
| op=copy-Pod w=2048 h=512 layout=universal-negative | dmd | 10.221–10.659x | 0.993–1.032x | 10.319–10.572x | 4.373–4.796x | 5.02% / 4.42% |
| op=copy-Pod w=2048 h=512 layout=universal-negative | ldc | 13.716–13.867x | 0.976–0.992x | 8.959–9.128x | 1.660–1.669x | 9.91% / 7.87% |
| op=convert-ubyte-float w=2048 h=512 layout=universal-negative | dmd | 32.988–33.750x | 1.005–1.031x | 33.043–34.263x | 11.286–18.243x | 0.45% / 3.70% |
| op=convert-ubyte-float w=2048 h=512 layout=universal-negative | ldc | 37.106–38.225x | 1.004–1.008x | 34.569–36.033x | 4.743–5.025x | 6.59% / 5.75% |
| op=copy-ubyte w=2048 h=512 layout=repeated-source | dmd | 9.884–9.955x | 1.111–1.120x | 4207.140–4301.763x | 0.855–0.897x | 6.75% / 9.15% |
| op=copy-ubyte w=2048 h=512 layout=repeated-source | ldc | 14.984–15.170x | 1.057–1.062x | 1174.989–1268.824x | 1.185–1.246x | 3.65% / 10.29% |
| op=copy-float w=2048 h=512 layout=repeated-source | dmd | 10.038–10.104x | 1.091–1.120x | 992.973–1355.955x | 0.541–0.823x | 11.08% / 49.52% |
| op=copy-float w=2048 h=512 layout=repeated-source | ldc | 22.326–22.365x | 1.058–1.061x | 182.382–309.696x | 1.156–1.263x | 7.77% / 82.99% |
| op=copy-Pod w=2048 h=512 layout=repeated-source | dmd | 10.403–10.634x | 1.096–1.110x | 388.850–490.505x | 1.051–1.170x | 9.67% / 37.12% |
| op=copy-Pod w=2048 h=512 layout=repeated-source | ldc | 15.256–16.513x | 1.049–1.056x | 141.610–189.041x | 1.041–1.131x | 9.32% / 45.94% |
| op=convert-ubyte-float w=2048 h=512 layout=repeated-source | dmd | 51.014–51.236x | 0.996–1.015x | 964.115–988.075x | 4.208–4.625x | 0.78% / 2.26% |
| op=convert-ubyte-float w=2048 h=512 layout=repeated-source | ldc | 62.675–63.897x | 1.013–1.022x | 1299.557–1495.693x | 1.013–1.141x | 3.79% / 19.46% |
| op=copy-ubyte w=2048 h=512 layout=zero-source | dmd | 3.118–3.166x | 0.999–1.002x | 3.126–3.158x | 4.537–4.639x | 2.37% / 2.60% |
| op=copy-ubyte w=2048 h=512 layout=zero-source | ldc | 3.844–4.041x | 0.945–0.962x | 2.535–2.617x | 1.478–1.500x | 5.29% / 3.38% |
| op=copy-float w=2048 h=512 layout=zero-source | dmd | 3.169–3.188x | 1.006–1.014x | 3.096–3.136x | 6.090–6.188x | 3.10% / 3.70% |
| op=copy-float w=2048 h=512 layout=zero-source | ldc | 5.820–5.980x | 0.920–0.924x | 3.103–3.301x | 1.472–1.512x | 4.97% / 6.26% |
| op=copy-Pod w=2048 h=512 layout=zero-source | dmd | 3.252–3.343x | 1.006–1.007x | 3.283–3.290x | 5.818–5.915x | 6.99% / 6.77% |
| op=copy-Pod w=2048 h=512 layout=zero-source | ldc | 4.330–4.452x | 0.948–0.978x | 2.528–2.632x | 1.890–1.921x | 1.35% / 5.52% |
| op=convert-ubyte-float w=2048 h=512 layout=zero-source | dmd | 8.694–8.804x | 0.996–1.000x | 8.651–8.826x | 21.353–21.748x | 8.70% / 8.30% |
| op=convert-ubyte-float w=2048 h=512 layout=zero-source | ldc | 9.457–9.576x | 0.991–0.996x | 9.053–9.222x | 5.602–5.759x | 4.98% / 6.95% |
