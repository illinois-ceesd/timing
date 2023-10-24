#!/bin/bash

function process_parallel_runlog(){

    # OUTPUT_PATH=${OUTPUT_PATH:-"."}
    run_timestamp=$1
    formatted_timestamp=$(date -d "${run_timestamp:0:8} ${run_timestamp:9:2}:${run_timestamp:11:2}:${run_timestamp:13:2}" +'%Y-%m-%d %H:%M')

    # Extract the year, month, day, hour, minute, and second
    year=${run_timestamp:0:4}
    month=${run_timestamp:4:2}
    day=${run_timestamp:6:2}
    hour=${run_timestamp:9:2}
    minute=${run_timestamp:11:2}
    second=${run_timestamp:13:2}

    # Create the reformatted timestamp
    reformatted_timestamp="${year}.${month}.${day}-${hour}.${minute}.${second}"

    run_name=$(ls *-rank0-${run_timestamp}.sqlite | sed -e 's/\(.*\)-rank.*$/\1/')
    nproc=$(ls *-rank0-${run_timestamp}.sqlite | sed -e 's/.*np\([0-9]\+\)-.*/\1/')

    RUN_CASENAME=${run_name}
    MAIN_YAML_FILE_NAME=${MAIN_YAML_FILE_NAME:-"../yaml/${RUN_CASENAME}-timing-data.yaml"}
    SUMMARY_FILE_ROOT=${SUMMARY_FILE_ROOT:-"${RUN_CASENAME}-timing-data"}
    YAML_OUTPUT_NAME="${SUMMARY_FILE_ROOT}-${run_timestamp}.yaml"
    SUMMARY_FILE_NAME="${SUMMARY_FILE_ROOT}-${run_timestamp}.sqlite"

    MIRGE_VERSION=${MIRGE_VERSION:-"Unknown"}
    DRIVER_VERSION=${DRIVER_VERSION:-"Unknown"}
    MIRGE_BRANCH=${MIRGE_BRANCH:-"Unknown"}
    DRIVER_BRANCH=${DRIVER_BRANCH:-"Unknown"}

    if [ ! -f ${MAIN_YAML_FILE_NAME} ]; then
        touch ${MAIN_YAML_FILE_NAME}
    fi

    printf "get_timing_data_from_log: Casename ${RUN_CASENAME}\n"
    printf "get_timing_data_from_log: Summary File ${SUMMARY_FILE_NAME}\n"
    printf "get_timing_data_from_log: YAML output ${YAML_OUTPUT_NAME}\n"

    set -x
    runalyzer-gather ${SUMMARY_FILE_NAME} ${run_name}-rank*-${run_timestamp}.sqlite
    #rm *-rank*-${run_timestamp}.sqlite
    set +x

    if [ ! -e "${SUMMARY_FILE_NAME}" ]; then
        printf "Failed to produce ${SUMMARY_FILE_NAME}, skipping.\n"
        unset run_timestamp
        unset run_name
        unset RUN_CASENAME
        unset nproc
        unset formatted_timestamp
        unset MAIN_YAML_FILE_NAME
        unset SUMMARY_FILE_ROOT
        unset YAML_OUTPUT_NAME
        unset SUMMARY_FILE_NAME
        return
    fi

    touch processed-${run_name}-${reformatted_timestamp}-sqlite

    CL_DEVICE=$(sqlite3 ${SUMMARY_FILE_NAME} 'SELECT cl_device_name FROM runs')
    STARTUP_TIME=$(runalyzer ${SUMMARY_FILE_NAME} -c 'print(q("select $t_init.max").fetchall()[0][0])' | grep -v INFO)
    FIRST_STEP=$(runalyzer ${SUMMARY_FILE_NAME} -c 'print(sum(p[0] for p in q("select $t_step.max").fetchall()[0:1]))' | grep -v INFO)
    FIRST_10_STEPS=$(runalyzer ${SUMMARY_FILE_NAME} -c 'print(sum(p[0] for p in q("select $t_step.max").fetchall()[0:10]))' | grep -v INFO)
    SECOND_10_STEPS=$(runalyzer ${SUMMARY_FILE_NAME} -c 'print(sum(p[0] for p in q("select $t_step.max").fetchall()[10:19]))' | grep -v INFO)
    MAX_PYTHON_MEM_USAGE=$(runalyzer ${SUMMARY_FILE_NAME} -c 'print(max(p[0] for p in q("select $memory_usage_python.max").fetchall()))' | grep -v INFO)
    MAX_GPU_MEM_USAGE=$(runalyzer ${SUMMARY_FILE_NAME} -c 'print(max(p[0] for p in q("select $memory_usage_gpu.max").fetchall()))' | grep -v INFO)
    TIMING_ARCH=$(uname -m)

    # --- Create a YAML-compatible text snippet with the timing info
    rm -f ${YAML_OUTPUT_NAME}
    printf "Creating YAML output: ${YAML_OUTPUT_NAME}\n"
    printf "run_date: ${formatted_timestamp}\nrun_host: Lassen\n" > ${YAML_OUTPUT_NAME}
    printf "cl_device: ${CL_DEVICE}\n" >> ${YAML_OUTPUT_NAME}
    printf "num_processors: ${nproc}\n" >> ${YAML_OUTPUT_NAME}
    printf "run_arch: ${TIMING_ARCH}\ngpu_arch: GV100GL\n" >> ${YAML_OUTPUT_NAME}
    printf "mirge_branch: ${MIRGE_BRANCH}\n" >> ${YAML_OUTPUT_NAME}
    printf "driver_branch: ${DRIVER_BRANCH}\n" >> ${YAML_OUTPUT_NAME}
    printf "mirge_version: ${MIRGE_VERSION}\n" >> ${YAML_OUTPUT_NAME}
    printf "driver_version: ${DRIVER_VERSION}\n" >> ${YAML_OUTPUT_NAME}
    printf "time_startup: ${STARTUP_TIME}\ntime_first_step: ${FIRST_STEP}\n" >> ${YAML_OUTPUT_NAME}
    printf "time_first_10: ${FIRST_10_STEPS}\ntime_second_10: ${SECOND_10_STEPS}\n" >> ${YAML_OUTPUT_NAME}
    printf "max_python_mem_usage: ${MAX_PYTHON_MEM_USAGE}\n" >> ${YAML_OUTPUT_NAME}
    printf "max_gpu_mem_usage: ${MAX_GPU_MEM_USAGE}\n---\n" >> ${YAML_OUTPUT_NAME}

    cat ${YAML_OUTPUT_NAME} >> ${MAIN_YAML_FILE_NAME}
    rm -f ${YAML_OUTPUT_NAME}
    mkdir -p summary_file_archive
    mv ${SUMMARY_FILE_NAME} summary_file_archive

    unset MAIN_YAML_FILE_NAME
    unset SUMMARY_FILE_ROOT
    unset run_timestamp
    unset run_name
    unset RUN_CASENAME
    unset nproc
    unset formatted_timestamp
    unset YAML_OUTPUT_NAME
    unset SUMMARY_FILE_NAME
}

SCALING_CASE_RUN_ROOT="y3-prediction-scaling-run"
SQL_DATA_SOURCE_DIR=${SQL_DATA_SOURCE_DIR:-"../../${SCALING_CASE_RUN_ROOT}/scalability_test/log_data"}
EMIRGE_HOME=${EMIRGE_HOME:-"../../emirge"}

conda deactivate
source ${EMIRGE_HOME}/config/activate_env.sh


# If $1 is given and it's a file
if [[ -f "$1" ]]; then

    candidate_timestamps=$(printf "$1" | sed -e 's/.*-\([0-9]\{8\}-[0-9]\{6\}\)\.sqlite/\1/')
    SQL_DATA_SOURCE_DIR=$(dirname "$1")
    ln -sf ${SQL_DATA_SOURCE_DIR}/*${candidate_timestamps}*.sqlite .
    
# If $1 is given and it's a directory or $1 isn't given at all
else

    SQL_DATA_SOURCE_DIR=${1:-"$SQL_DATA_SOURCE_DIR"}
    if [[ ! -d "$SQL_DATA_SOURCE_DIR" ]]; then
        printf "Error: ${SQL_DATA_SOURCE_DIR} is not a valid directory.\n"
        exit 1
    fi
    ln -sf ${SQL_DATA_SOURCE_DIR}/*-rank*.sqlite .
    candidate_timestamps=$(ls *-rank0-*.sqlite | sed -e 's/.*-\([0-9]\{8\}-[0-9]\{6\}\)\.sqlite/\1/' | sort -u)
fi

# Get a list of already processed timestamps and convert them to YYYYMMDD-HHMMSS format
processed_timestamps=$(ls *-sqlite | sed -e 's/.*-\([0-9]\{4\}\)\.\([0-9]\{2\}\)\.\([0-9]\{2\}\)-\([0-9]\{2\}\)\.\([0-9]\{2\}\)\.\([0-9]\{2\}\)-sqlite/\1\2\3-\4\5\6/' | sort -u)


# Process candidate datasets
for timestamp in $candidate_timestamps
do
    if ! echo "$processed_timestamps" | grep -q "$timestamp"; then
        printf "Processing timestamp: ${timestamp}\n"
        process_parallel_runlog ${timestamp}
    else
        printf "Skipping already processed timestamp: ${timestamp}\n"
    fi
done

rm -f *-rank*sqlite

conda deactivate
