#!/bin/bash

. utilities.sh

set -e
set -x
set -o pipefail

NONOPT_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--branch)
            DRIVER_BRANCH="$2"
            shift
            shift
            ;;
        -f|--fork)
            DRIVER_FORK="$2"
            shift
            shift
            ;;
        -d|--driver)
            DRIVER_REPO_NAME="$2"
            shift
            shift
            ;;
        -i|--install)
            DRIVER_INSTALL_NAME="$2"
            shift 
            shift
            ;;
        --overwrite)
            OVERWRITE=true
            shift
            ;;
        -*|--*)
            echo "install_mirgecom: Unknown option $1"
            exit 1
            ;;
        *)
            NONOPT_ARGS+=("$1")
            shift
            ;;
    esac
done

set -- "${NONOPT_ARGS[@]}"

date

# exename="prediction"
TIMING_PKG_NAME=${DRIVER_INSTALL_NAME:-"y2-prediction"}
timestamp=$(date "+%Y.%m.%d-%H.%M.%S")
TIMING_HOME=$(pwd)
TIMING_HOST=$(hostname)
TIMING_DATE=$(date "+%Y-%m-%d %H:%M")
TIME_SINCE_EPOCH=$(date +%s)
TIMING_PLATFORM=$(uname)
TIMING_ARCH=$(uname -m)
TIMING_REPO="illinois-ceesd/timing.git"
TIMING_BRANCH="main"
TIMING_ENV_NAME="${TIMING_PKG_NAME}.timing.env"

SUMMARY_FILE_ROOT="${TIMING_PKG_NAME}"
YAML_FILE_NAME_ROOT="${TIMING_PKG_NAME}-timings.yaml"
BATCH_OUTPUT_FILE="${SUMMARY_FILE_ROOT}_${timestamp}.out"
LOGDIR="${TIMING_PKG_NAME}_logs"
# EXEOPTS="--lazy --log"
SQL_PATH="./log_data"


MIRGE_BRANCH="production"
MIRGE_FORK="illinois-ceesd"
MIRGE_INSTALL="emirge"

DRIVER_REPO_NAME=${DRIVER_REPO_NAME:-"drivers_y2-prediction"}
DRIVER_FORK=${DRIVER_FORK:-"illinois-ceesd"}
DRIVER_REPO="${DRIVER_FORK}/${DRIVER_REPO_NAME}"
DRIVER_BRANCH=${DRIVER_BRANCH:-"overhaul-testing"}
DRIVER_NAME=${DRIVER_INSTALL_NAME:-"y2-prediction"}
TIMING_DATA_PATH="${DRIVER_NAME}_timing_data"

EMIRGE_HOME="${TIMING_HOME}/${MIRGE_INSTALL}"
MIRGECOM_HOME="${EMIRGE_HOME}/mirgecom"

# -- Run the case (platform-dependent)
GPU_ARCH="Unknown"

case $TIMING_HOST in

    # --- Run the timing test in a batch job on Lassen@LLC
    lassen*)
        echo "Resolved Host: Lassen"
        TIMING_HOST="Lassen"
        GPU_ARCH="GV100GL"
        ;;
    # --- Run the timing test on an unknown/generic machine 
    *)
        printf "Host: Unknown\n"
        PYOPENCL_TEST=port:pthread python -O -m mpi4py ./${exename}.py -i timing_params.yaml ${EXEOPTS}
        ;;
esac

printf "Running on Host: ${TIMING_HOST}\n"
printf "GPU_ARCH: ${GPU_ARCH}\n"

# -- Install conda env, dependencies and MIRGE-Com via *emirge*
if [ -f "INSTALL_MIRGECOM" ]
then
    install_mirgecom -f "${MIRGE_FORK}" -b "${MIRGE_BRANCH}" -i "${EMIRGE_HOME}" -e "${TIMING_ENV_NAME}" --overwrite
    rm -f INSTALL_MIRGECOM
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
#rm -Rf ${DRIVER_NAME}
#install_mirgecom_driver -b ${DRIVER_BRANCH} -n ${DRIVER_REPO_NAME} -i ${DRIVER_NAME} -f ${DRIVER_FORK} --overwrite

cd ${DRIVER_NAME}
DRIVER_PATH=$(pwd)
DRIVER_HASH=$(git rev-parse origin/${DRIVER_BRANCH})
cd -

mkdir -p ${TIMING_DATA_PATH}
cd ${TIMING_DATA_PATH}
TIMING_DATA_PATH=$(pwd)
cd -

# Run the driver-specific timing script through batch (if necessary)
#. generate_mirge_batch_script.sh -c "${DRIVER_PATH}/scripts/single_timing.sh -c single_timing -e ${PLATFORM_ENV_FILE} -o ${TIMING_DATA_PATH} -p ${DRIVER_PATH}" -e ${EMIRGE_HOME} -o ${DRIVER_NAME}-single-timing-batch-script.sh -x Yes


# Post-process the logpyle sqlite data into yaml files
for datafile in ${TIMING_DATA_PATH}/single_timing*-rank0.sqlite
do
    log_file=$(basename $datafile)
    driver_casename=$(printf "$log_file" | sed 's/single_timing_//' | sed 's/-rank0\.sqlite//')
    printf "Creating YAML data for ${driver_casename} from ${datafile}.\n"
    . get_timing_data_from_log.sh -o ${TIMING_DATA_PATH} ${datafile}
done

