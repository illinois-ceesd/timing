# Automated timings for CEESD production-ish runs

To run (should work anywhere):
```
curl -L -O https://raw.githubusercontent.com/illinois-ceesd/timing/main/time-y1-nozzle.sh
bash ./time-y1-nozzle.sh
```

To plot (requires matplotlib, yaml, pandas):
```bash
$ python utils/plot-timings.py
```
