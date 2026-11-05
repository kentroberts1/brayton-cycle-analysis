# Brayton Cycle Analysis

A computational thermodynamics project examining the Brayton cycle behind a turbojet engine, and how much regeneration and intercooling actually help once you account for compressor and turbine losses.

I compared four setups at a turbine inlet temperature of 1400 K and pressure ratio of 12:

1. Simple cycle
2. Regeneration
3. Two-stage intercooling
4. Intercooling + regeneration

Each one is solved as both an ideal cycle and real cycle. I also ran the turbojet version for static thrust and swept the pressure ratio from 2 to 40. 
Initial values: compressor efficiency 0.85, turbine efficiency 0.88, regenerator effectiveness 0.80

## Results

| Configuration | Efficiency (ideal) | Efficiency (real) | Net work, real (kJ/kg) |
| --- | --- | --- | --- |
| Simple | 50.8% | 36.2% | 277.3 |
| Regeneration | 58.2% | 42.2% | 277.3 |
| Intercooling | 47.1% | 34.9% | 339.2 |
| Intercooling + regeneration | 65.5% | 48.6% | 339.2 |

![Efficiency by configuration](figures/fig06_efficiency_bars.png)

Results and Analysis:

- Real component losses drop the simple cycle efficiency from about 51% to 36%. Over half the turbine's work goes into running the compressor.
- Regeneration adds about 6% of efficiency without changing net work.
- Intercooling by itself surprisingly decreased efficiency, even though net work went up 22%. This is due to air leaving the compressor colder, leading to more required heat addition from the combustor.
- Combining intercooling and regeneration is much better than either alone, increasing efficiency from 36.2% to 48.6%. This stems from colder compressed air giving the regenerator a bigger temperature difference to work with (273 K vs 108 K without intercooling).
- Regeneration only helps up to a pressure ratio of about 17. Past that, the turbine exhaust is colder than the compressor exit.
- For the turbojet, intercooling gave about 10% more specific thrust but about 15% worse fuel consumption per unit thrust.

### T-s and P-v diagrams (intercooling + regeneration)

![T-s and P-v diagrams](figures/fig04_ic_regen.png)

### Efficiency vs pressure ratio

![Efficiency vs pressure ratio](figures/fig07_eta_vs_rp.png)

The rest of the figures (one diagram per configuration, an overlay of all four cycles, net work vs pressure ratio, and turbojet thrust/TSFC) are in [`figures/`](figures).

## Repo layout

```
python/brayton_numbers.py    all the thermodynamics; writes results/*.csv
matlab/brayton_figures.m     reads the CSVs, makes figures/ and results/tables.txt
matlab/cycle_path.m          helper for drawing process paths on the diagrams
results/                     CSV output and formatted tables
figures/                     the nine plots
```

Splitting the process up rather then using only Python or only MATLAB allows for ease of troubleshooting. Issues in numerical results leads to finding the problem in Python, while plotting issues can be fixed in MATLAB.

## Running it

```bash
python python/brayton_numbers.py
```

Then in MATLAB:

```matlab
run('matlab/brayton_figures.m')
```

Run the Python script first. To try a different initial condition, change the inputs near the top of and rerun both.

## Checking the numbers

Before trusting the code I worked the simple, regenerative and intercooled cycles by hand, and the program matches to rounding (e.g. T2s = 585.8 K and an ideal efficiency of 50.8%, which also matches the closed-form 1 − 1/rp^((k−1)/k)). Every case also closes the first law, stays under the Carnot limit (79.4%), and shows entropy increasing across the real compressor and turbine.

## Assumptions and limitations

This uses cold-air-standard assumptions: constant specific heats (cp = 1.005 kJ/kg·K, k = 1.4), combustion modeled as constant-pressure heat addition, no fuel mass, and no pressure losses in the combustor or heat exchangers. All of that makes the efficiencies a bit optimistic, but I wouldn't expect it to change which configuration comes out ahead.

Things I'd add next:

- Temperature-dependent air properties from the air tables
- Pressure losses across the heat exchangers
- Flight speed in the turbojet model, so propulsive efficiency can be included

## Use of AI tools

I used Claude AI to help write and organize the Python and MATLAB code, the plots and this documentation. The analysis setup, results and conclusions are mine, and I verified the numbers as described above.
