# Timing status (last ran on: 2023.07.21)

[![y3-prediction-scalability](https://github.com/illinois-ceesd/timing/actions/workflows/y3-prediction-scalability.yaml/badge.svg)](https://github.com/illinois-ceesd/timing/actions/workflows/y3-prediction-scalability.yaml) [![y2-prediction-timing](https://github.com/illinois-ceesd/timing/actions/workflows/y2-prediction-timing.yaml/badge.svg)](https://github.com/illinois-ceesd/timing/actions/workflows/y2-prediction-timing.yaml) [![isolator-timing](https://github.com/illinois-ceesd/timing/actions/workflows/isolator-timing.yaml/badge.svg)](https://github.com/illinois-ceesd/timing/actions/workflows/isolator-timing.yaml) [![flame1d-timing](https://github.com/illinois-ceesd/timing/actions/workflows/flame1d-timing.yaml/badge.svg)](https://github.com/illinois-ceesd/timing/actions/workflows/flame1d-timing.yaml) [![nozzle-timing](https://github.com/illinois-ceesd/timing/actions/workflows/nozzle-timing.yaml/badge.svg)](https://github.com/illinois-ceesd/timing/actions/workflows/nozzle-timing.yaml)

# Current timing plots

## Y3 Prediction: weak scaling on Lassen

### Startup, compile, and runtime

![Y3Prediction-scalability-full](plots/y3-prediction-scalability-full.png)

### Step details

![Y3Prediction-scalability-step](plots/y3-prediction-scalability-step-full.png)

### Scaling

![Y3Prediction-weak-scaling](plots/weak_scaling_y3-prediction-scalability-step-full.png)

## Y2 Prediction

### Smoke Test
#### Startup, compile, and step

![Y2Prediction-smoke_test-full](plots/y2-prediction-single-smoke_test-full.png)

#### Step details

![Y2Prediction-smoke_test-step](plots/y2-prediction-single-smoke_test-step-recent.png)

### Smoke Test 3D
#### Startup, compile, and step

![Y2Prediction-smoke_test_3d-full](plots/y2-prediction-single-smoke_test_3d-full.png)

#### Step details

![Y2Prediction-smoke_test_3d-step](plots/y2-prediction-single-smoke_test_3d-step-recent.png)

### Smoke Test KS
#### Startup, compile, and step

![Y2Prediction-smoke_test_ks-full](plots/y2-prediction-single-smoke_test_ks-full.png)

#### Step details

![Y2Prediction-smoke_test_ks-step](plots/y2-prediction-single-smoke_test_ks-step-recent.png)

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
