# Timing status (last ran on: 2024.12.04)

[![y3-prediction-scalability](https://github.com/illinois-ceesd/timing/actions/workflows/y3-prediction-scalability.yaml/badge.svg)](https://github.com/illinois-ceesd/timing/actions/workflows/y3-prediction-scalability.yaml)

# Current timing plots

## Y3 Prediction: weak scaling on Lassen

### Latest runs
#### Startup, compile, and runtime

![Y3Prediction-scalability-full](plots/y3-prediction-scalability-recent.png)

#### Step details

![Y3Prediction-scalability-step](plots/y3-prediction-scalability-step-recent.png)

### Lifetime monitoring

#### Scaling

![Y3Prediction-weak-scaling](plots/weak_scaling_y3-prediction-scalability-step-full.png)


#### Startup, compile, and runtime

![Y3Prediction-scalability-full](plots/y3-prediction-scalability-full.png)

#### Step details

![Y3Prediction-scalability-step](plots/y3-prediction-scalability-step-full.png)


# Plotting the data

To plot (requires matplotlib, yaml, pandas):
```bash
$ python utils/plot-multi-timings.py y3-prediction/<platform>/yaml/*.yaml
```
