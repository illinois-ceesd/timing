#!/bin/bash

. utilities.sh

set -e
set -x
set -o pipefail

DRIVER_BRANCH=""
DRIVER_FORK=""
DRIVER_REPO_NAME=""
DRIVER_INSTALL_NAME=""
OVERWRITE=false

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
DRIVER_INSTALL_PATH=${DRIVER_NAME}-single_timing
rm -Rf ${DRIVER_INSTALL_PATH}
install_mirgecom_driver -b ${DRIVER_BRANCH} -n ${DRIVER_REPO_NAME} -i ${DRIVER_INSTALL_PATH} -f ${DRIVER_FORK} --overwrite

cd ${DRIVER_INSTALL_PATH}
DRIVER_PATH=$(pwd)
DRIVER_HASH=$(git rev-parse origin/${DRIVER_BRANCH})
cd -

mkdir -p ${TIMING_DATA_PATH}
cd ${TIMING_DATA_PATH}
TIMING_DATA_PATH=$(pwd)
cd -

# Run the driver-specific timing script through batch (if necessary)
. generate_mirge_batch_script.sh -c "${DRIVER_PATH}/scripts/single_timing.sh -c single_timing -e ${PLATFORM_ENV_FILE} -o ${TIMING_DATA_PATH} -p ${DRIVER_PATH}" -e ${EMIRGE_HOME} -o ${DRIVER_NAME}-single-timing-batch-script.sh -x Yes

date

# Post-process the logpyle sqlite data into yaml files
for datafile in ${TIMING_DATA_PATH}/single_timing*-rank0.sqlite
do

    log_file=$(basename $datafile)
    driver_casename=$(printf "$log_file" | sed 's/single_timing_//' | sed 's/-rank0\.sqlite//')
    printf "Creating YAML data for ${driver_casename} from ${datafile}.\n"
    DATA_YAML="${TIMING_DATA_PATH}/single_timing_${driver_casename}-timing-data.yaml"
    DATA_PATH_ROOT=$(printf "${DATA_YAML}" | sed 's/\.yaml//')
    DATA_SQLITE="${DATA_PATH_ROOT}.sqlite"
    OUTPUT_SQLITE="${DATA_PATH_ROOT}_${timestamp}.sqlite"
    OUTPUT_YAML="${DATA_PATH_ROOT}_${timestamp}.yaml"

    rm -f ${DATA_YAML} ${DATA_SQLITE} ${OUTPUT_SQLITE} ${OUTPUT_YAML}
    . get_timing_data_from_log.sh -o ${TIMING_DATA_PATH} ${datafile}

    if [[ ! -f "${DATA_YAML}" ]]; then
        printf "Expected YAML data summary file not found (${DATA_YAML})."
        exit 1
    fi


    printf "run_date: ${TIMING_DATE}\nrun_host: ${TIMING_HOST}\n" > ${OUTPUT_YAML}
    printf "run_epoch: ${TIME_SINCE_EPOCH}\nrun_platform: ${TIMING_PLATFORM}\n" >> ${OUTPUT_YAML}
    printf "run_arch: ${TIMING_ARCH}\ngpu_arch: ${GPU_ARCH}\n" >> ${OUTPUT_YAML}
    printf "mirge_version: ${MIRGE_HASH}\n" >> ${OUTPUT_YAML}
    printf "driver_version: ${DRIVER_HASH}\ndriver_md5sum: ${DRIVER_MD5SUM}\n" >> ${OUTPUT_YAML}
    cat ${DATA_YAML} >> ${OUTPUT_YAML}

    mv ${DATA_SQLITE} ${OUTPUT_SQLITE}
done
date

# Users should set special keys for using git over
# ssh for security concerns. This snippet will use
# a pre-arranged ssh key if the user provides one
# and indicates it with the TESTING_SSH_KEY environment
# variable.
# ===== To create a key:
# - Run ssh-keygen:
# $ ssh-keygen
# [enter a <keyname> when prompted]
# - Put the key(s) in a /secure/filesystem/location:
# $ mv <keyname>* /secure/filesystem/location
# - Add the key to GIT:
# $ [browse to] https://github.com/illinois-ceesd/timing/settings/keys/new
# $ Choose (New SSH key)
# $ Paste in the contents of /secure/filesystem/location/<keyname>.pub
# - Set the ENV variable before using this script:
# $ export TESTING_SSH_KEY=/secure/filesystem/location/<keyname>
if [ ! -z "${TESTING_SSH_KEY}" ]; then
    eval $(ssh-agent)
    trap "kill $SSH_AGENT_PID" EXIT
    ssh-add ${TESTING_SSH_KEY}
fi

rm -rf timing-data-update
git clone -b ${TIMING_BRANCH} git@github.com:${TIMING_REPO} timing-data-update
for datafile in ${TIMING_DATA_PATH}/single_timing*-rank0.sqlite
do

    log_file=$(basename $datafile)
    driver_casename=$(printf "$log_file" | sed 's/single_timing_//' | sed 's/-rank0\.sqlite//')
    REPO_TIMING_DATA_YAML="single_timing_${driver_casename}-timing-data.yaml"
    # printf "Creating YAML data for ${driver_casename} from ${datafile}.\n"
    DATA_YAML="${TIMING_DATA_PATH}/${REPO_TIMING_DATA_YAML}"
    DATA_PATH_ROOT=$(printf "${DATA_YAML}" | sed 's/\.yaml//')
    OUTPUT_SQLITE="${DATA_PATH_ROOT}_${timestamp}.sqlite"
    OUTPUT_YAML="${DATA_PATH_ROOT}_${timestamp}.yaml"

    REPO_DATA_PATH="timing-data-update/${TIMING_PKG_NAME}"
    mkdir -p ${REPO_DATA_PATH}/yaml
    touch ${REPO_DATA_PATH}/yaml/${REPO_TIMING_DATA_YAML}
    cat ${OUTPUT_YAML} >> ${REPO_DATA_PATH}/yaml/${REPO_TIMING_DATA_YAML}

    # ---- Update the timing file with the current test data
    mkdir -p ${REPO_DATA_PATH}/sql
    cp ${OUTPUT_SQLITE} ${REPO_DATA_PATH}/sql
    cd timing-data-update
    git add ${TIMING_PKG_NAME}
    # ---- Commit the new data to the repo
    # printf "COMMIT&PUSH: ${TIMING_HOST} ${TIMING_DATE}\n"
    (git commit -am "Automatic commit: ${TIMING_HOST} ${TIMING_DATE}" && git push)
    cd ../

done

rm -rf timing-data-update
date
