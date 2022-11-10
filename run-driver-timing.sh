#!/bin/bash

. utilities.sh

set -e
set -x
set -o pipefail

date

exename="prediction"
TIMING_PKG_NAME="y2-prediction"
timestamp=$(date "+%Y.%m.%d-%H.%M.%S")
TIMING_HOME=$(pwd)
TIMING_HOST=$(hostname)
TIMING_DATE=$(date "+%Y-%m-%d %H:%M")
TIME_SINCE_EPOCH=$(date +%s)
TIMING_PLATFORM=$(uname)
TIMING_ARCH=$(uname -m)
TIMING_REPO="illinois-ceesd/timing.git"
TIMING_BRANCH="main"
TIMING_ENV_NAME="${TIMING_PKG_NAME}.lazy.timing.env"
MIRGE_BRANCH="production"
MIRGE_FORK="illinois-ceesd"
MIRGE_INSTALL="emirge"
DRIVER_REPO_NAME="drivers_y2-prediction"
DRIVER_FORK="overhaul-testing"
DRIVER_REPO="${DRIVER_FORK}/${DRIVER_REPO_NAME}"
DRIVER_BRANCH="main"
DRIVER_NAME="y2-prediction"
SUMMARY_FILE_ROOT="${TIMING_PKG_NAME}_lazy"
YAML_FILE_NAME="${TIMING_PKG_NAME}-timings.yaml"
BATCH_OUTPUT_FILE="${SUMMARY_FILE_ROOT}_${timestamp}.out"
LOGDIR="${TIMING_PKG_NAME}_logs"
EXEOPTS="--lazy --log"
SQL_PATH="./log_data"

# -- Install conda env, dependencies and MIRGE-Com via *emirge*
if [ -f "INSTALL_MIRGECOM" ]
then
    install_mirgecom -f "${MIRGE_FORK}" -b "${MIRGE_BRANCH}" -i "${TIMING_HOME}/${MIRGE_INSTALL}" -e "${TIMING_ENV_NAME}" --overwrite
    rm -f INSTALL_MIRGECOM
fi

# -- Activate the env we just created above
# export EMIRGE_HOME="${TIMING_HOME}/${MIRGE_INSTALL}"
source ${EMIRGE_HOME}/config/activate_env.sh
cd ${MIRGECOM_HOME}

if [[ -d "scripts" ]]; then
    . scripts/utilities.sh
fi

# -- Grab and merge the branch with the case-dependent features
MIRGE_HASH=$(git rev-parse origin/${MIRGE_BRANCH})

# --- Grab the case driver repo
rm -Rf ${DRIVER_NAME}
install_mirgecom_driver -b ${DRIVER_BRANCH} -n ${DRIVER_REPO_NAME} -i ${DRIVER_NAME} -f ${DRIVER_FORK} --overwrite
