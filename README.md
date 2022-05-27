# Status of production timings

[![isolator-timing](https://github.com/illinois-ceesd/timing/actions/workflows/isolator-timing.yaml/badge.svg)](https://github.com/illinois-ceesd/timing/actions/workflows/isolator-timing.yaml)

[![flame1d-timing](https://github.com/illinois-ceesd/timing/actions/workflows/flame1d-timing.yaml/badge.svg)](https://github.com/illinois-ceesd/timing/actions/workflows/flame1d-timing.yaml)

[![nozzle-timing](https://github.com/illinois-ceesd/timing/actions/workflows/nozzle-timing.yaml/badge.svg)](https://github.com/illinois-ceesd/timing/actions/workflows/nozzle-timing.yaml)

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
