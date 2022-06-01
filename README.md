Timings last ran on: 2022.06.01

# Status of production timings

[![isolator-timing](https://github.com/illinois-ceesd/timing/actions/workflows/isolator-timing.yaml/badge.svg)](https://github.com/illinois-ceesd/timing/actions/workflows/isolator-timing.yaml)

[![flame1d-timing](https://github.com/illinois-ceesd/timing/actions/workflows/flame1d-timing.yaml/badge.svg)](https://github.com/illinois-ceesd/timing/actions/workflows/flame1d-timing.yaml)

[![nozzle-timing](https://github.com/illinois-ceesd/timing/actions/workflows/nozzle-timing.yaml/badge.svg)](https://github.com/illinois-ceesd/timing/actions/workflows/nozzle-timing.yaml)

# Current timing plots

## Isolator - 2D inert

### Startup, compile, and step

![Isolator2D-inert-full](plots/isolator-full-recent.png)

### Step details

![Isolator2D-inert-step](plots/isolator-step-recent.png)

## Nozzle - 2D single gas

### Startup, compile, and step

![Nozzle-full](plots/nozzle-full-recent.png)

### Step details

![Nozzle-step](plots/nozzle-step-recent.png)

## Flame1D - 2D mixture with combustion

### Startup, compile, and step

![Flame1D-full](plots/flame1d-full-recent.png)

### Step details

![Flame1D-step](plots/flame1d-step-recent.png)

# Automated timings for CEESD production-ish runs

To run (should work anywhere):

```bash
$ curl -L -O https://raw.githubusercontent.com/illinois-ceesd/timing/main/time-y1-nozzle.sh
$ bash ./time-y1-nozzle.sh
```

To plot (requires matplotlib, yaml, pandas):
```bash
$ python utils/plot-timings.py
```
