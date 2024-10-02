#!/bin/bash -l

set -e
set -x
set -o pipefail

date

export TIMING_TIMESTAMP=$(date "+%Y.%m.%d-%H.%M.%S")
export TIMING_HOME=$(pwd)
export TIMING_HOST=$(hostname)
export TIMING_DATE=$(date "+%Y-%m-%d %H:%M")
export TIME_SINCE_EPOCH=$(date +%s)
export TIMING_PLATFORM=$(uname -n)
export TIMING_ARCH=$(uname -m)
export TIMING_REPO="illinois-ceesd/timing.git"
export TIMING_BRANCH="tioga"
export TIMING_ENV_NAME="tioga.timing.env"
export MIRGE_BRANCH="tioga"

source ./install-mirgecom.sh

# DRIVER_REPO="illinois-ceesd/drivers_y1-nozzle"
# DRIVER_BRANCH="main"
# DRIVER_NAME="y1-production-nozzle-lazy"
# SUMMARY_FILE_ROOT="${exename}_lazy"
# YAML_FILE_NAME="${exename}-lazy-timings.yaml"
# BATCH_OUTPUT_FILE="${SUMMARY_FILE_ROOT}_${timestamp}.out"
# LOGDIR="${exename}_lazy_logs"
# EXEOPTS="--lazy --log"
# SQL_PATH="./log_data"

