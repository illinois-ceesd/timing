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
TIMING_DATA_PATH="${DRIVER_NAME}_timing_data"
SQL_PATH="./log_data"
EMIRGE_HOME="${TIMING_HOME}/${MIRGE_INSTALL}"
MIRGECOM_HOME="${EMIRGE_HOME}/mirgecom"

# -- Install conda env, dependencies and MIRGE-Com via *emirge*
if [ -f "INSTALL_MIRGECOM" ]
then
    install_mirgecom -f "${MIRGE_FORK}" -b "${MIRGE_BRANCH}" -i "${EMIRGE_HOME}" -e "${TIMING_ENV_NAME}" --overwrite
    rm -f INSTALL_MIRGECOM
else
fi

# -- Activate the env we just created above
# export EMIRGE_HOME="${TIMING_HOME}/${MIRGE_INSTALL}"
source ${EMIRGE_HOME}/config/activate_env.sh
cd ${MIRGECOM_HOME}
MIRGECOM_HOME=$(pwd)

if [[ -d "scripts" ]]; then
    . scripts/utilities.sh
fi

MIRGE_HASH=$(git rev-parse origin/${MIRGE_BRANCH})
cd -
PLATFORM_ENV_FILE="${MIRGECOM_HOME}/scripts/mirge-testing-env.sh"

# --- Grab the case driver repo
rm -Rf ${DRIVER_NAME}
install_mirgecom_driver -b ${DRIVER_BRANCH} -n ${DRIVER_REPO_NAME} -i ${DRIVER_NAME} -f ${DRIVER_FORK} --overwrite

cd ${DRIVER_NAME}
DRIVER_PATH=$(pwd)
DRIVER_HASH=$(git rev-parse origin/${DRIVER_BRANCH})
cd -

mkdir -p ${TIMING_DATA_PATH}
cd ${TIMING_DATA_PATH}
TIMING_DATA_PATH=$(pwd)
cd -

. generate_mirge_batch_script.sh -c "${DRIVER_PATH}/scripts/single_timing.sh" -o timing-batch-script.sh

