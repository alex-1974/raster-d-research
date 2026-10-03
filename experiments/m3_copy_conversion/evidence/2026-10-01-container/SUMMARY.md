# Public copy / exact conversion — container baseline

Pinned production: `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`. All six processes pass 96 timed cases, 32 additional semantic cases and public error/no-write/shared-disjoint controls. All output/source fingerprints match across compilers/processes.

Public is end-to-end. Approved is unchanged private semantic traversal with prior approval supplied by fixtures (even flat copy does not use memcpy here). C++ is execution-only, using per-row memcpy for unit-stride copy and scalar-source exact conversion, without D validation/classification; an external C ABI call is added. Relation is the unchanged exact affine classifier alone plus stride/base retrieval, not the complete public validation. Ratios diagnose opportunities; these are not equivalent complete-library comparisons or promoted candidates. Costs are not subtracted to infer causality.

Twelve cyclic rounds rotate all four paths through each position three times. Two warmups; destination reset and complete source/output/padding checks outside every timer. Large positive execution samples are required; tiny zero medians are retained and ratios omitted. Frequency/thermal controls are unchanged. AArch64 unqualified. No production selection without XPS and a validation-preserving candidate.

| Case | Compiler | Public/Approved | Public/C++ | Public ns (three medians) | Relation ns (three medians) | Public process spread |
| --- | --- | --- | --- | --- | --- | --- |
| op=copy-ubyte w=31 h=17 layout=contiguous | dmd | 0.024–0.024x | below clock resolution | [100, 100, 100] | [88700, 87800, 88600] | 0.00% |
| op=copy-ubyte w=31 h=17 layout=contiguous | ldc | 0.000–0.000x | below clock resolution | [0, 0, 0] | [40200, 40300, 40300] | below clock resolution |
| op=copy-float w=31 h=17 layout=contiguous | dmd | 0.022–0.023x | below clock resolution | [100, 100, 100] | [88600, 87850, 88500] | 0.00% |
| op=copy-float w=31 h=17 layout=contiguous | ldc | 0.000–0.000x | below clock resolution | [0, 0, 0] | [40400, 40300, 40300] | below clock resolution |
| op=copy-Pod w=31 h=17 layout=contiguous | dmd | 0.024–0.048x | 1.000–2.000x | [200, 100, 100] | [88800, 88600, 87000] | 100.00% |
| op=copy-Pod w=31 h=17 layout=contiguous | ldc | 0.083–0.083x | 1.000–1.000x | [100, 100, 100] | [40200, 40300, 40400] | 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=contiguous | dmd | 0.736–0.744x | 32.000–32.000x | [3200, 3200, 3200] | [485700, 471250, 553000] | 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=contiguous | ldc | 1.750–1.826x | 20.500–21.000x | [2100, 2050, 2100] | [163300, 169850, 161800] | 2.44% |
| op=copy-ubyte w=31 h=17 layout=padded | dmd | 21.506–22.107x | below clock resolution | [92850, 93650, 91400] | [87600, 88250, 88500] | 2.46% |
| op=copy-ubyte w=31 h=17 layout=padded | ldc | 37.545–37.636x | below clock resolution | [41400, 41400, 41300] | [40300, 40300, 40300] | 0.24% |
| op=copy-float w=31 h=17 layout=padded | dmd | 21.102–21.721x | 928.500–934.000x | [93000, 93400, 92850] | [87350, 87600, 88650] | 0.59% |
| op=copy-float w=31 h=17 layout=padded | ldc | 34.500–34.583x | below clock resolution | [41400, 41500, 41450] | [40300, 40300, 40300] | 0.24% |
| op=copy-Pod w=31 h=17 layout=padded | dmd | 21.857–22.059x | 922.000–1836.000x | [91800, 92200, 93750] | [88300, 88650, 87850] | 2.12% |
| op=copy-Pod w=31 h=17 layout=padded | ldc | 34.500–36.000x | 414.000–828.000x | [41500, 41400, 41400] | [40300, 40300, 40400] | 0.24% |
| op=convert-ubyte-float w=31 h=17 layout=padded | dmd | 110.453–118.326x | 4749.500–5088.000x | [474950, 508800, 495200] | [472050, 462950, 490300] | 7.13% |
| op=convert-ubyte-float w=31 h=17 layout=padded | ldc | 136.583–147.500x | 1622.500–1639.000x | [162250, 163900, 162350] | [160250, 161450, 160450] | 1.02% |
| op=copy-ubyte w=31 h=17 layout=negative-source | dmd | 21.291–21.647x | below clock resolution | [92000, 91550, 91750] | [87250, 87700, 88950] | 0.49% |
| op=copy-ubyte w=31 h=17 layout=negative-source | ldc | 37.636–37.636x | below clock resolution | [41400, 41400, 41400] | [40200, 40200, 40300] | 0.00% |
| op=copy-float w=31 h=17 layout=negative-source | dmd | 21.453–21.535x | below clock resolution | [92250, 92600, 92400] | [87550, 87550, 88300] | 0.38% |
| op=copy-float w=31 h=17 layout=negative-source | ldc | 34.500–34.583x | below clock resolution | [41500, 41500, 41400] | [40300, 40400, 40300] | 0.24% |
| op=copy-Pod w=31 h=17 layout=negative-source | dmd | 21.952–23.214x | 922.000–975.000x | [97500, 92200, 92450] | [87650, 88150, 88350] | 5.75% |
| op=copy-Pod w=31 h=17 layout=negative-source | ldc | 34.583–34.625x | 415.000–830.000x | [41500, 41550, 41500] | [40400, 40300, 40350] | 0.12% |
| op=convert-ubyte-float w=31 h=17 layout=negative-source | dmd | 112.151–116.035x | 4822.500–4989.500x | [498950, 485500, 482250] | [475250, 461800, 488150] | 3.46% |
| op=convert-ubyte-float w=31 h=17 layout=negative-source | ldc | 135.875–147.375x | 1626.000–1768.500x | [163050, 176850, 162600] | [160000, 173300, 160000] | 8.76% |
| op=copy-ubyte w=31 h=17 layout=negative-both | dmd | 22.826–23.024x | below clock resolution | [98150, 96650, 96700] | [89650, 89050, 91500] | 1.55% |
| op=copy-ubyte w=31 h=17 layout=negative-both | ldc | 37.545–37.818x | below clock resolution | [41300, 41600, 41400] | [40300, 40500, 40200] | 0.73% |
| op=copy-float w=31 h=17 layout=negative-both | dmd | 21.558–21.651x | below clock resolution | [93050, 92700, 93100] | [88350, 88250, 88700] | 0.43% |
| op=copy-float w=31 h=17 layout=negative-both | ldc | 34.458–34.750x | below clock resolution | [41500, 41700, 41350] | [40300, 40500, 40200] | 0.85% |
| op=copy-Pod w=31 h=17 layout=negative-both | dmd | 22.036–22.167x | 925.500–931.000x | [92700, 92550, 93100] | [88350, 88200, 88800] | 0.59% |
| op=copy-Pod w=31 h=17 layout=negative-both | ldc | 34.583–34.667x | 415.000–416.000x | [41500, 41600, 41500] | [40200, 40450, 40300] | 0.24% |
| op=convert-ubyte-float w=31 h=17 layout=negative-both | dmd | 108.035–114.614x | 4645.500–5043.000x | [464550, 485850, 504300] | [486600, 467550, 510350] | 8.56% |
| op=convert-ubyte-float w=31 h=17 layout=negative-both | ldc | 125.423–137.417x | 1623.000–1649.000x | [163050, 164900, 162300] | [160000, 162100, 165650] | 1.60% |
| op=copy-ubyte w=31 h=17 layout=universal | dmd | 21.628–23.047x | 57.594–61.219x | [93000, 97950, 92150] | [88100, 87450, 88650] | 6.29% |
| op=copy-ubyte w=31 h=17 layout=universal | ldc | 37.545–37.818x | 25.812–26.000x | [41400, 41600, 41300] | [40200, 40600, 40300] | 0.73% |
| op=copy-float w=31 h=17 layout=universal | dmd | 21.581–21.698x | 49.105–51.694x | [92800, 93300, 93050] | [88550, 87450, 89100] | 0.54% |
| op=copy-float w=31 h=17 layout=universal | ldc | 34.458–34.792x | 24.324–24.559x | [41400, 41750, 41350] | [40200, 40500, 40200] | 0.97% |
| op=copy-Pod w=31 h=17 layout=universal | dmd | 21.721–21.952x | 48.368–49.158x | [91900, 92200, 93400] | [88500, 88600, 88350] | 1.63% |
| op=copy-Pod w=31 h=17 layout=universal | ldc | 34.583–35.583x | 24.412–25.118x | [42400, 42700, 41500] | [41100, 41400, 40300] | 2.89% |
| op=convert-ubyte-float w=31 h=17 layout=universal | dmd | 62.326–72.384x | 889.286–915.167x | [268000, 311250, 274550] | [273700, 302750, 298550] | 16.14% |
| op=convert-ubyte-float w=31 h=17 layout=universal | ldc | 79.500–88.455x | 318.000–325.000x | [95400, 97300, 97500] | [92800, 93500, 94800] | 2.20% |
| op=copy-ubyte w=31 h=17 layout=universal-negative | dmd | 21.477–22.179x | 54.794–58.125x | [92350, 93150, 93000] | [88300, 88450, 89000] | 0.87% |
| op=copy-ubyte w=31 h=17 layout=universal-negative | ldc | 36.909–37.000x | 25.375–25.438x | [40600, 40600, 40700] | [39500, 39500, 39600] | 0.25% |
| op=copy-float w=31 h=17 layout=universal-negative | dmd | 21.523–22.593x | 49.842–53.667x | [96600, 97150, 94700] | [90700, 90850, 94250] | 2.59% |
| op=copy-float w=31 h=17 layout=universal-negative | ldc | 33.833–33.917x | 23.882–23.941x | [40650, 40700, 40600] | [39700, 39600, 39550] | 0.25% |
| op=copy-Pod w=31 h=17 layout=universal-negative | dmd | 22.393–22.548x | 50.838–56.882x | [94700, 94050, 96700] | [92700, 92250, 88900] | 2.82% |
| op=copy-Pod w=31 h=17 layout=universal-negative | ldc | 34.000–34.042x | 24.000–24.029x | [40850, 40800, 40800] | [39600, 39650, 39600] | 0.12% |
| op=convert-ubyte-float w=31 h=17 layout=universal-negative | dmd | 69.093–75.570x | 990.333–1083.167x | [297100, 303500, 324950] | [302200, 292600, 306950] | 9.37% |
| op=convert-ubyte-float w=31 h=17 layout=universal-negative | ldc | 81.417–88.727x | 325.333–327.333x | [97700, 97600, 98200] | [95500, 95400, 96100] | 0.61% |
| op=copy-ubyte w=31 h=17 layout=repeated-source | dmd | 22.393–22.738x | below clock resolution | [97250, 95500, 94050] | [90450, 88950, 91650] | 3.40% |
| op=copy-ubyte w=31 h=17 layout=repeated-source | ldc | 37.636–38.000x | below clock resolution | [41400, 41400, 41800] | [40300, 40200, 40400] | 0.97% |
| op=copy-float w=31 h=17 layout=repeated-source | dmd | 21.466–22.756x | below clock resolution | [97850, 95550, 94450] | [90750, 90350, 89750] | 3.60% |
| op=copy-float w=31 h=17 layout=repeated-source | ldc | 29.464–34.250x | below clock resolution | [41050, 41250, 41100] | [39800, 40100, 39900] | 0.49% |
| op=copy-Pod w=31 h=17 layout=repeated-source | dmd | 22.095–23.655x | 928.000–993.500x | [93650, 92800, 99350] | [92650, 95200, 88000] | 7.06% |
| op=copy-Pod w=31 h=17 layout=repeated-source | ldc | 34.167–37.364x | 410.000–411.000x | [41100, 41000, 41100] | [39700, 39900, 39950] | 0.24% |
| op=convert-ubyte-float w=31 h=17 layout=repeated-source | dmd | 108.081–117.000x | 4647.500–5031.000x | [464750, 474500, 503100] | [475300, 489900, 483900] | 8.25% |
| op=convert-ubyte-float w=31 h=17 layout=repeated-source | ldc | 135.375–150.545x | 1624.500–1656.000x | [162450, 165600, 165350] | [160550, 162450, 163150] | 1.94% |
| op=copy-ubyte w=31 h=17 layout=zero-source | dmd | 6.750–6.833x | 16.676–17.938x | [28350, 28500, 28700] | [24400, 24700, 24200] | 1.23% |
| op=copy-ubyte w=31 h=17 layout=zero-source | ldc | 9.091–9.091x | 6.250–6.250x | [10000, 10000, 10000] | [8900, 8900, 8900] | 0.00% |
| op=copy-float w=31 h=17 layout=zero-source | dmd | 6.674–6.744x | 15.211–17.059x | [29000, 28900, 28700] | [24400, 24550, 24400] | 1.05% |
| op=copy-float w=31 h=17 layout=zero-source | ldc | 8.833–9.636x | 5.579–6.235x | [10600, 10600, 10600] | [9500, 9500, 9500] | 0.00% |
| op=copy-Pod w=31 h=17 layout=zero-source | dmd | 6.605–6.833x | 14.947–16.765x | [28500, 28400, 28700] | [24700, 24200, 24250] | 1.06% |
| op=copy-Pod w=31 h=17 layout=zero-source | ldc | 8.917–9.727x | 5.632–6.294x | [10700, 10700, 10700] | [9500, 9500, 9600] | 0.00% |
| op=convert-ubyte-float w=31 h=17 layout=zero-source | dmd | 17.148–17.558x | 251.000–251.667x | [75300, 75500, 75450] | [70900, 71000, 71100] | 0.27% |
| op=convert-ubyte-float w=31 h=17 layout=zero-source | ldc | 23.250–25.455x | 93.000–93.333x | [27900, 28000, 27900] | [25700, 25900, 25700] | 0.36% |
| op=copy-ubyte w=256 h=128 layout=contiguous | dmd | 0.005–0.005x | 1.562–1.778x | [1250, 1350, 1600] | [5244400, 5334150, 5722600] | 28.00% |
| op=copy-ubyte w=256 h=128 layout=contiguous | ldc | 0.013–0.013x | 1.000–1.286x | [900, 900, 900] | [2385050, 2513750, 2503200] | 0.00% |
| op=copy-float w=256 h=128 layout=contiguous | dmd | 0.013–0.018x | 1.440–1.941x | [3600, 4950, 3800] | [5192100, 5209250, 5729950] | 37.50% |
| op=copy-float w=256 h=128 layout=contiguous | ldc | 0.033–0.035x | 1.104–1.109x | [2550, 2650, 2550] | [2395050, 2407900, 2342550] | 3.92% |
| op=copy-Pod w=256 h=128 layout=contiguous | dmd | 0.020–0.021x | 1.069–1.133x | [5550, 5400, 5850] | [5292700, 5137700, 5361100] | 8.33% |
| op=copy-Pod w=256 h=128 layout=contiguous | ldc | 0.068–0.069x | 1.020–1.041x | [5050, 5100, 5100] | [2379950, 2466750, 2385400] | 0.99% |
| op=convert-ubyte-float w=256 h=128 layout=contiguous | dmd | 0.637–0.703x | 61.869–66.850x | [200550, 189700, 188700] | [27587950, 27582450, 28872450] | 6.28% |
| op=convert-ubyte-float w=256 h=128 layout=contiguous | ldc | 1.672–1.714x | 40.258–42.322x | [124600, 124800, 124850] | [9676450, 10066300, 10166800] | 0.20% |
| op=copy-ubyte w=256 h=128 layout=padded | dmd | 19.927–20.965x | 4621.875–5253.952x | [5546250, 5485000, 5516650] | [5187700, 5072850, 5363600] | 1.12% |
| op=copy-ubyte w=256 h=128 layout=padded | ldc | 35.324–36.611x | 2950.412–3114.188x | [2491350, 2507850, 2405550] | [2411550, 2481800, 2323650] | 4.25% |
| op=copy-float w=256 h=128 layout=padded | dmd | 20.087–20.819x | 2008.643–2039.400x | [5624200, 5608350, 5797150] | [5179900, 5121750, 5168250] | 3.37% |
| op=copy-float w=256 h=128 layout=padded | ldc | 31.681–33.203x | 890.574–964.755x | [2492250, 2556600, 2404550] | [2369900, 2429150, 2335350] | 6.32% |
| op=copy-Pod w=256 h=128 layout=padded | dmd | 20.473–20.738x | 936.802–964.398x | [5448850, 5440550, 5667650] | [5207800, 5207950, 5371450] | 4.17% |
| op=copy-Pod w=256 h=128 layout=padded | ldc | 32.704–34.454x | 434.991–474.269x | [2466200, 2559900, 2457700] | [2361700, 2470200, 2400000] | 4.16% |
| op=convert-ubyte-float w=256 h=128 layout=padded | dmd | 99.038–108.939x | 8480.662–9447.970x | [31178300, 27562150, 29144400] | [29751100, 27269600, 28927200] | 13.12% |
| op=convert-ubyte-float w=256 h=128 layout=padded | ldc | 133.494–141.484x | 3137.113–3336.290x | [9827250, 10342500, 9725050] | [9608300, 10502500, 9776650] | 6.35% |
| op=copy-ubyte w=256 h=128 layout=negative-source | dmd | 20.040–21.631x | 5210.045–6010.722x | [5731050, 5302550, 5409650] | [5548200, 5018100, 5152850] | 8.08% |
| op=copy-ubyte w=256 h=128 layout=negative-source | ldc | 34.714–37.043x | 2759.944–3167.188x | [2483950, 2533750, 2403950] | [2396700, 2418750, 2322150] | 5.40% |
| op=copy-float w=256 h=128 layout=negative-source | dmd | 19.459–19.817x | 1816.267–1990.204x | [5373550, 5352500, 5448800] | [5141850, 5129400, 5227000] | 1.80% |
| op=copy-float w=256 h=128 layout=negative-source | ldc | 31.838–33.258x | 900.339–963.000x | [2503800, 2520950, 2434050] | [2367300, 2433550, 2345400] | 3.57% |
| op=copy-Pod w=256 h=128 layout=negative-source | dmd | 19.185–21.375x | 904.443–980.546x | [5294950, 5517100, 5905850] | [5020750, 5252750, 5349150] | 11.54% |
| op=copy-Pod w=256 h=128 layout=negative-source | ldc | 32.633–33.400x | 449.541–459.434x | [2435000, 2494950, 2465400] | [2338700, 2379050, 2351200] | 2.46% |
| op=convert-ubyte-float w=256 h=128 layout=negative-source | dmd | 100.253–107.951x | 8018.750–8528.103x | [27263750, 28502000, 28995550] | [27244200, 28618900, 28566000] | 6.35% |
| op=convert-ubyte-float w=256 h=128 layout=negative-source | ldc | 132.577–149.614x | 2999.045–3481.492x | [10119250, 9896850, 10966700] | [9684350, 9692200, 11143400] | 10.81% |
| op=copy-ubyte w=256 h=128 layout=negative-both | dmd | 20.654–21.944x | 5090.000–5341.429x | [5608500, 5853500, 5839650] | [5106050, 5455650, 5438650] | 4.37% |
| op=copy-ubyte w=256 h=128 layout=negative-both | ldc | 34.882–36.209x | 2984.562–3299.867x | [2474900, 2387650, 2479900] | [2375550, 2409300, 2392700] | 3.86% |
| op=copy-float w=256 h=128 layout=negative-both | dmd | 19.872–23.249x | 1931.966–2163.379x | [5843200, 6273800, 5699300] | [5366100, 5578450, 5246150] | 10.08% |
| op=copy-float w=256 h=128 layout=negative-both | ldc | 31.358–33.004x | 911.170–930.833x | [2414600, 2509700, 2513250] | [2355800, 2443350, 2421950] | 4.09% |
| op=copy-Pod w=256 h=128 layout=negative-both | dmd | 19.295–22.253x | 971.822–1028.442x | [5822300, 6170650, 5733750] | [5530500, 5374150, 5534700] | 7.62% |
| op=copy-Pod w=256 h=128 layout=negative-both | ldc | 33.149–33.924x | 461.630–467.396x | [2477200, 2492800, 2537500] | [2456150, 2335450, 2426150] | 2.43% |
| op=convert-ubyte-float w=256 h=128 layout=negative-both | dmd | 98.938–105.998x | 8018.444–8600.420x | [28866400, 30082200, 29671450] | [28665500, 28767450, 29199150] | 4.21% |
| op=convert-ubyte-float w=256 h=128 layout=negative-both | ldc | 135.565–140.362x | 2885.943–3208.578x | [9936950, 10267450, 10100800] | [9878750, 9944250, 10085100] | 3.33% |
| op=copy-ubyte w=256 h=128 layout=universal | dmd | 20.684–21.435x | 50.823–57.577x | [5600200, 5685750, 5524450] | [5254200, 5151100, 5338700] | 2.92% |
| op=copy-ubyte w=256 h=128 layout=universal | ldc | 35.692–37.418x | 25.106–26.298x | [2591700, 2578100, 2471700] | [2453550, 2532600, 2404550] | 4.85% |
| op=copy-float w=256 h=128 layout=universal | dmd | 20.196–23.025x | 51.737–58.477x | [5566900, 5574100, 6295100] | [5145150, 5144200, 5669250] | 13.08% |
| op=copy-float w=256 h=128 layout=universal | ldc | 31.936–33.214x | 22.977–23.903x | [2562450, 2543500, 2465450] | [2423500, 2530950, 2442000] | 3.93% |
| op=copy-Pod w=256 h=128 layout=universal | dmd | 19.025–23.505x | 49.287–57.843x | [5769200, 5478300, 6238350] | [5483650, 5466700, 5554400] | 13.87% |
| op=copy-Pod w=256 h=128 layout=universal | ldc | 32.297–33.774x | 22.791–23.868x | [2454550, 2563450, 2525600] | [2383050, 2522450, 2453200] | 4.44% |
| op=convert-ubyte-float w=256 h=128 layout=universal | dmd | 59.143–66.131x | 879.832–1036.238x | [16012950, 16692750, 18963150] | [15600900, 15824800, 17534300] | 18.42% |
| op=convert-ubyte-float w=256 h=128 layout=universal | ldc | 79.335–83.039x | 325.072–337.431x | [5890650, 6107500, 5900050] | [5679650, 5872350, 5649350] | 3.68% |
| op=copy-ubyte w=256 h=128 layout=universal-negative | dmd | 20.321–20.925x | 57.058–57.489x | [5615100, 5620250, 5700050] | [5208050, 5212400, 5611300] | 1.51% |
| op=copy-ubyte w=256 h=128 layout=universal-negative | ldc | 36.315–36.937x | 25.417–26.021x | [2529600, 2557900, 2511200] | [2383900, 2518250, 2364550] | 1.86% |
| op=copy-float w=256 h=128 layout=universal-negative | dmd | 20.527–21.822x | 53.906–55.566x | [5970600, 5789550, 5874550] | [5422500, 5385850, 5953800] | 3.13% |
| op=copy-float w=256 h=128 layout=universal-negative | ldc | 32.531–33.693x | 23.258–24.273x | [2508150, 2604500, 2495600] | [2393600, 2605800, 2464800] | 4.36% |
| op=copy-Pod w=256 h=128 layout=universal-negative | dmd | 18.922–22.635x | 51.797–58.017x | [5581150, 5746400, 6268700] | [5688650, 5426600, 6187150] | 12.32% |
| op=copy-Pod w=256 h=128 layout=universal-negative | ldc | 32.193–34.545x | 22.262–24.170x | [2440400, 2599500, 2420950] | [2384800, 2480150, 2346800] | 7.38% |
| op=convert-ubyte-float w=256 h=128 layout=universal-negative | dmd | 63.631–68.217x | 993.841–1050.090x | [18087900, 18278000, 19216650] | [17614400, 17736900, 18364150] | 6.24% |
| op=convert-ubyte-float w=256 h=128 layout=universal-negative | ldc | 77.550–83.453x | 318.172–345.047x | [5727100, 6279850, 5950250] | [5596950, 5878550, 5650100] | 9.65% |
| op=copy-ubyte w=256 h=128 layout=repeated-source | dmd | 22.176–22.998x | 5451.409–6501.222x | [5851100, 6139350, 5996550] | [5318550, 5472250, 6148200] | 4.93% |
| op=copy-ubyte w=256 h=128 layout=repeated-source | ldc | 34.278–36.932x | 3010.125–3629.857x | [2408100, 2540900, 2380600] | [2310250, 2433450, 2385200] | 6.73% |
| op=copy-float w=256 h=128 layout=repeated-source | dmd | 20.141–21.385x | 2355.587–2593.733x | [5835900, 5866950, 5417850] | [5404250, 5268500, 5357600] | 8.29% |
| op=copy-float w=256 h=128 layout=repeated-source | ldc | 31.888–34.637x | 1108.114–1195.773x | [2437850, 2630700, 2449150] | [2394300, 2604150, 2396850] | 7.91% |
| op=copy-Pod w=256 h=128 layout=repeated-source | dmd | 20.128–21.606x | 1490.816–1602.529x | [5478800, 5608850, 5665100] | [5114050, 5159150, 5266300] | 3.40% |
| op=copy-Pod w=256 h=128 layout=repeated-source | ldc | 32.648–35.454x | 787.758–818.081x | [2536050, 2600550, 2442050] | [2493150, 2531550, 2425300] | 6.49% |
| op=convert-ubyte-float w=256 h=128 layout=repeated-source | dmd | 102.169–110.626x | 8896.810–9554.190x | [30095700, 28024950, 30442600] | [28303000, 27460900, 30260600] | 8.63% |
| op=convert-ubyte-float w=256 h=128 layout=repeated-source | ldc | 134.585–140.507x | 3074.422–3280.467x | [9841400, 10214850, 9838150] | [9754300, 10226850, 9665650] | 3.83% |
| op=copy-ubyte w=256 h=128 layout=zero-source | dmd | 6.284–6.580x | 17.195–18.259x | [1704950, 1691100, 1797600] | [1440750, 1473850, 1493200] | 6.30% |
| op=copy-ubyte w=256 h=128 layout=zero-source | ldc | 9.006–9.256x | 6.331–6.567x | [622650, 646200, 631750] | [549650, 568400, 580000] | 3.78% |
| op=copy-float w=256 h=128 layout=zero-source | dmd | 6.244–6.961x | 15.178–17.678x | [1896850, 1694600, 1766450] | [1488350, 1479100, 1435500] | 11.93% |
| op=copy-float w=256 h=128 layout=zero-source | ldc | 8.172–8.455x | 5.833–6.064x | [624750, 649800, 630700] | [558850, 565450, 579150] | 4.01% |
| op=copy-Pod w=256 h=128 layout=zero-source | dmd | 6.292–7.267x | 15.409–17.971x | [1929150, 1685400, 1651050] | [1489350, 1478550, 1398250] | 16.84% |
| op=copy-Pod w=256 h=128 layout=zero-source | ldc | 8.541–9.938x | 5.908–6.924x | [634500, 741900, 633300] | [555400, 620200, 558950] | 17.15% |
| op=convert-ubyte-float w=256 h=128 layout=zero-source | dmd | 16.573–17.227x | 248.188–268.717x | [4479800, 4628650, 4850350] | [4280100, 4164600, 4310950] | 8.27% |
| op=convert-ubyte-float w=256 h=128 layout=zero-source | ldc | 22.523–23.862x | 92.533–93.325x | [1665600, 1677050, 1679850] | [1547000, 1538850, 1517700] | 0.86% |
| op=copy-ubyte w=2048 h=512 layout=contiguous | dmd | 0.003–0.004x | 0.663–0.911x | [29200, 29900, 31900] | [83845850, 84971900, 89143050] | 9.25% |
| op=copy-ubyte w=2048 h=512 layout=contiguous | ldc | 0.013–0.015x | 0.703–0.928x | [32300, 30300, 34500] | [41104350, 39946750, 38980550] | 13.86% |
| op=copy-float w=2048 h=512 layout=contiguous | dmd | 0.022–0.023x | 1.185–1.406x | [199100, 197050, 208850] | [85894250, 87735550, 85633750] | 5.99% |
| op=copy-float w=2048 h=512 layout=contiguous | ldc | 0.061–0.065x | 1.106–1.293x | [159700, 157950, 165250] | [40671150, 39046650, 38680400] | 4.62% |
| op=copy-Pod w=2048 h=512 layout=contiguous | dmd | 0.039–0.042x | 1.021–1.033x | [366150, 353750, 378300] | [84246800, 86177950, 96425700] | 6.94% |
| op=copy-Pod w=2048 h=512 layout=contiguous | ldc | 0.137–0.144x | 0.898–1.013x | [344850, 342750, 362100] | [38527650, 39538150, 38416850] | 5.65% |
| op=convert-ubyte-float w=2048 h=512 layout=contiguous | dmd | 0.686–0.709x | 63.294–65.320x | [6266100, 6352000, 6450350] | [451547600, 451745800, 477960650] | 2.94% |
| op=convert-ubyte-float w=2048 h=512 layout=contiguous | ldc | 1.692–1.760x | 43.813–44.318x | [4279450, 4234600, 4263000] | [158696100, 175861050, 162446550] | 1.06% |
| op=copy-ubyte w=2048 h=512 layout=padded | dmd | 10.450–10.560x | 2226.854–2440.853x | [97145950, 93082500, 98733800] | [87785950, 82824700, 88402550] | 6.07% |
| op=copy-ubyte w=2048 h=512 layout=padded | ldc | 18.118–18.690x | 733.046–1310.138x | [44282650, 49700550, 41164900] | [40499550, 49516500, 39341100] | 20.74% |
| op=copy-float w=2048 h=512 layout=padded | dmd | 10.124–10.489x | 489.999–644.679x | [96652400, 93989600, 99377250] | [87043700, 86339450, 87243850] | 5.73% |
| op=copy-float w=2048 h=512 layout=padded | ldc | 16.317–17.716x | 295.559–355.959x | [42447750, 45135650, 41585200] | [40994050, 41811700, 40647250] | 8.54% |
| op=copy-Pod w=2048 h=512 layout=padded | dmd | 10.233–10.658x | 249.751–273.218x | [93872450, 94555700, 100011300] | [85112250, 86690950, 87932400] | 6.54% |
| op=copy-Pod w=2048 h=512 layout=padded | ldc | 16.884–17.503x | 117.207–125.253x | [42562200, 45652300, 43256050] | [39501900, 41458300, 40535200] | 7.26% |
| op=convert-ubyte-float w=2048 h=512 layout=padded | dmd | 49.309–51.897x | 4708.104–4956.973x | [470893950, 463042000, 488509700] | [450375600, 458176600, 479853200] | 5.50% |
| op=convert-ubyte-float w=2048 h=512 layout=padded | ldc | 63.321–70.390x | 1695.198–1826.720x | [166298900, 179201250, 168116000] | [160774150, 168912800, 160680900] | 7.76% |
| op=copy-ubyte w=2048 h=512 layout=negative-source | dmd | 10.403–10.640x | 1677.084–1897.320x | [90217550, 98528700, 99173750] | [81576700, 87696350, 92508850] | 9.93% |
| op=copy-ubyte w=2048 h=512 layout=negative-source | ldc | 16.962–18.616x | 858.159–1118.921x | [43685250, 44624250, 43637900] | [41862350, 42998600, 42100300] | 2.26% |
| op=copy-float w=2048 h=512 layout=negative-source | dmd | 10.071–10.657x | 328.411–432.833x | [94674600, 95797450, 100222550] | [85960800, 89120200, 89980450] | 5.86% |
| op=copy-float w=2048 h=512 layout=negative-source | ldc | 15.263–16.385x | 138.000–257.485x | [45146550, 43553600, 41854200] | [44973000, 39911150, 39695000] | 7.87% |
| op=copy-Pod w=2048 h=512 layout=negative-source | dmd | 10.289–10.413x | 144.510–163.205x | [94993500, 97681500, 102279300] | [86327450, 87799250, 90350750] | 7.67% |
| op=copy-Pod w=2048 h=512 layout=negative-source | ldc | 15.026–16.160x | 66.201–75.019x | [42713100, 43458250, 42008150] | [40045950, 39868800, 38934500] | 3.45% |
| op=convert-ubyte-float w=2048 h=512 layout=negative-source | dmd | 49.603–50.999x | 1722.794–2534.913x | [477957800, 470581250, 462565800] | [458339900, 452612600, 467537950] | 3.33% |
| op=convert-ubyte-float w=2048 h=512 layout=negative-source | ldc | 64.200–68.512x | 1109.847–1270.321x | [169905450, 169845700, 158597150] | [163588100, 163604000, 156398250] | 7.13% |
| op=copy-ubyte w=2048 h=512 layout=negative-both | dmd | 10.380–10.829x | 1543.353–2271.110x | [92207050, 97848600, 93388300] | [86119650, 86124750, 83950100] | 6.12% |
| op=copy-ubyte w=2048 h=512 layout=negative-both | ldc | 18.058–18.700x | 812.363–1192.754x | [42202250, 44131900, 44515300] | [39631850, 41976350, 41854800] | 5.48% |
| op=copy-float w=2048 h=512 layout=negative-both | dmd | 10.304–11.333x | 294.084–414.688x | [92548250, 98405550, 104065250] | [83259000, 87049350, 84784250] | 12.44% |
| op=copy-float w=2048 h=512 layout=negative-both | ldc | 16.304–16.699x | 208.992–234.298x | [41780100, 44434650, 42874800] | [38604200, 39565450, 40981550] | 6.35% |
| op=copy-Pod w=2048 h=512 layout=negative-both | dmd | 9.957–10.281x | 133.308–135.824x | [97040250, 93453600, 95041900] | [87275550, 86846950, 86973050] | 3.84% |
| op=copy-Pod w=2048 h=512 layout=negative-both | ldc | 15.463–15.588x | 64.129–71.002x | [42094500, 43471050, 41825800] | [39254850, 42115550, 38936450] | 3.93% |
| op=convert-ubyte-float w=2048 h=512 layout=negative-both | dmd | 48.034–51.452x | 1816.801–2640.209x | [476365250, 484214350, 476011400] | [464114650, 466219250, 472382650] | 1.72% |
| op=convert-ubyte-float w=2048 h=512 layout=negative-both | ldc | 63.740–66.532x | 911.264–1157.042x | [172225700, 173779800, 161157000] | [162569650, 166475400, 155948600] | 7.83% |
| op=copy-ubyte w=2048 h=512 layout=universal | dmd | 10.442–10.644x | 27.982–29.158x | [97007400, 94088250, 97775200] | [85065150, 85973550, 87034000] | 3.92% |
| op=copy-ubyte w=2048 h=512 layout=universal | ldc | 17.894–18.338x | 12.737–13.209x | [41664350, 44485200, 43358050] | [38944600, 41406350, 40683650] | 6.77% |
| op=copy-float w=2048 h=512 layout=universal | dmd | 9.986–10.736x | 26.432–26.783x | [95573350, 97586150, 94212850] | [84423200, 86841500, 84368150] | 3.58% |
| op=copy-float w=2048 h=512 layout=universal | ldc | 16.159–16.714x | 11.637–11.981x | [42536000, 46032750, 43232500] | [40562800, 42130150, 40805550] | 8.22% |
| op=copy-Pod w=2048 h=512 layout=universal | dmd | 10.613–10.689x | 25.423–26.146x | [96702950, 99773850, 95810600] | [87140950, 90595300, 87833750] | 4.14% |
| op=copy-Pod w=2048 h=512 layout=universal | ldc | 16.041–16.442x | 11.415–11.966x | [41142300, 43781100, 43669900] | [39483450, 40846500, 40934700] | 6.41% |
| op=convert-ubyte-float w=2048 h=512 layout=universal | dmd | 28.378–29.382x | 433.862–463.244x | [266348050, 276070300, 266258650] | [263918700, 263638350, 254865550] | 3.69% |
| op=convert-ubyte-float w=2048 h=512 layout=universal | ldc | 37.565–39.585x | 158.690–166.917x | [96285200, 101103100, 102077800] | [90234700, 93455450, 97434000] | 6.02% |
| op=copy-ubyte w=2048 h=512 layout=universal-negative | dmd | 10.510–11.013x | 28.315–29.940x | [98788300, 93967950, 98521800] | [87808550, 84968800, 89493250] | 5.13% |
| op=copy-ubyte w=2048 h=512 layout=universal-negative | ldc | 17.607–18.212x | 12.428–12.772x | [41133750, 43045550, 42919800] | [39022250, 41788900, 40203700] | 4.65% |
| op=copy-float w=2048 h=512 layout=universal-negative | dmd | 10.319–10.549x | 26.462–27.707x | [94305750, 100507650, 94612550] | [84471600, 93021850, 86355400] | 6.58% |
| op=copy-float w=2048 h=512 layout=universal-negative | ldc | 16.008–16.392x | 11.216–11.614x | [42074300, 40808550, 42902900] | [40350100, 38405100, 40843050] | 5.13% |
| op=copy-Pod w=2048 h=512 layout=universal-negative | dmd | 10.012–10.598x | 25.129–26.471x | [96303850, 98367950, 96128450] | [85525800, 87756100, 85131200] | 2.33% |
| op=copy-Pod w=2048 h=512 layout=universal-negative | ldc | 16.313–16.775x | 11.505–11.894x | [44665750, 41554150, 42671700] | [42371450, 38731550, 39960750] | 7.49% |
| op=convert-ubyte-float w=2048 h=512 layout=universal-negative | dmd | 31.821–32.877x | 477.640–497.122x | [294512750, 304300700, 297104900] | [289238250, 294818900, 287804900] | 3.32% |
| op=convert-ubyte-float w=2048 h=512 layout=universal-negative | ldc | 38.683–41.670x | 162.173–176.955x | [99241950, 109455450, 103847300] | [96267450, 104535350, 100174750] | 10.29% |
| op=copy-ubyte w=2048 h=512 layout=repeated-source | dmd | 10.476–10.661x | 5989.572–6677.385x | [93137850, 95486600, 96166600] | [84635150, 86494750, 86837600] | 3.25% |
| op=copy-ubyte w=2048 h=512 layout=repeated-source | ldc | 17.144–18.950x | 2956.766–3168.683x | [44203650, 43112550, 44044700] | [41721500, 39963150, 41354100] | 2.53% |
| op=copy-float w=2048 h=512 layout=repeated-source | dmd | 10.348–10.498x | 921.315–1544.592x | [93375750, 92598300, 94987600] | [84223700, 82415200, 85321300] | 2.58% |
| op=copy-float w=2048 h=512 layout=repeated-source | ldc | 16.292–16.556x | 691.354–713.273x | [42974700, 41659450, 41481250] | [40664400, 39608850, 39067950] | 3.60% |
| op=copy-Pod w=2048 h=512 layout=repeated-source | dmd | 10.254–10.471x | 408.325–648.657x | [94194700, 95222800, 95813450] | [84519850, 85924900, 85968800] | 1.72% |
| op=copy-Pod w=2048 h=512 layout=repeated-source | ldc | 16.812–17.648x | 299.245–320.279x | [44707250, 42469000, 42644450] | [41517750, 39578150, 40927050] | 5.27% |
| op=convert-ubyte-float w=2048 h=512 layout=repeated-source | dmd | 50.048–50.536x | 4637.060–5317.658x | [454431850, 469317600, 467953900] | [441836000, 456026150, 460112800] | 3.28% |
| op=convert-ubyte-float w=2048 h=512 layout=repeated-source | ldc | 67.103–69.116x | 1712.413–1781.561x | [166609450, 166446550, 174414850] | [162579000, 158977100, 172719300] | 4.79% |
| op=copy-ubyte w=2048 h=512 layout=zero-source | dmd | 3.574–3.608x | 9.575–9.911x | [32620750, 31889950, 31565900] | [23226300, 23205150, 22976500] | 3.34% |
| op=copy-ubyte w=2048 h=512 layout=zero-source | ldc | 4.952–5.213x | 3.448–3.599x | [11708800, 12269350, 11935450] | [9176400, 9677150, 9305050] | 4.79% |
| op=copy-float w=2048 h=512 layout=zero-source | dmd | 3.535–3.640x | 8.941–9.440x | [34920100, 31680900, 33953950] | [24769850, 23713800, 23961250] | 10.22% |
| op=copy-float w=2048 h=512 layout=zero-source | ldc | 4.458–4.633x | 3.240–3.302x | [11811200, 12728600, 12533850] | [9377450, 9648500, 9710550] | 7.77% |
| op=copy-Pod w=2048 h=512 layout=zero-source | dmd | 3.553–3.601x | 8.124–8.987x | [32057250, 33499700, 33624700] | [22924350, 23794100, 24536900] | 4.89% |
| op=copy-Pod w=2048 h=512 layout=zero-source | ldc | 4.442–4.717x | 2.994–3.262x | [11487800, 12150900, 11994350] | [9084700, 9772900, 9284350] | 5.77% |
| op=convert-ubyte-float w=2048 h=512 layout=zero-source | dmd | 8.297–8.836x | 129.072–134.827x | [76055800, 80224300, 79790850] | [66730800, 70172550, 70961900] | 5.48% |
| op=convert-ubyte-float w=2048 h=512 layout=zero-source | ldc | 11.738–12.525x | 49.478–52.140x | [29787050, 31383150, 30841850] | [25124850, 26390350, 26606000] | 5.36% |
