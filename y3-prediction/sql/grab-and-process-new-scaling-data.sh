#!/bin/bash

function process_parallel_runlog(){

    # OUTPUT_PATH=${OUTPUT_PATH:-"."}
    run_timestamp=$1
    formatted_timestamp=$(date -d "${run_timestamp:0:8} ${run_timestamp:9:2}:${run_timestamp:11:2}:${run_timestamp:13:2}" +'%Y-%m-%d %H:%M')
    
    run_name=$(ls *-rank0-${run_timestamp}.sqlite | sed -e 's/\(.*\)-rank.*$/\1/')
    nproc=$(ls *-rank0-${run_timestamp}.sqlite | sed -e 's/.*np\([0-9]\+\)-.*/\1/')

    RUN_CASENAME=${run_name}
    MAIN_YAML_FILE_NAME=${MAIN_YAML_FILE_NAME:-"../yaml/${RUN_CASENAME}-timing-data.yaml"}
    SUMMARY_FILE_ROOT=${SUMMARY_FILE_ROOT:-"${RUN_CASENAME}-timing-data"}
    YAML_OUTPUT_NAME="${SUMMARY_FILE_ROOT}-${run_timestamp}.yaml"
    SUMMARY_FILE_NAME="${SUMMARY_FILE_ROOT}-${run_timestamp}.sqlite"

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

    CL_DEVICE=$(sqlite3 ${SUMMARY_FILE_NAME} 'SELECT cl_device_name FROM runs')
    STARTUP_TIME=$(runalyzer -m ${SUMMARY_FILE_NAME} -c 'print(q("select $t_init.max").fetchall()[0][0])' | grep -v INFO)
    FIRST_STEP=$(runalyzer -m ${SUMMARY_FILE_NAME} -c 'print(sum(p[0] for p in q("select $t_step.max").fetchall()[0:1]))' | grep -v INFO)
    FIRST_10_STEPS=$(runalyzer -m ${SUMMARY_FILE_NAME} -c 'print(sum(p[0] for p in q("select $t_step.max").fetchall()[0:10]))' | grep -v INFO)
    SECOND_10_STEPS=$(runalyzer -m ${SUMMARY_FILE_NAME} -c 'print(sum(p[0] for p in q("select $t_step.max").fetchall()[10:19]))' | grep -v INFO)
    MAX_PYTHON_MEM_USAGE=$(runalyzer -m ${SUMMARY_FILE_NAME} -c 'print(max(p[0] for p in q("select $memory_usage_python.max").fetchall()))' | grep -v INFO)
    MAX_GPU_MEM_USAGE=$(runalyzer -m ${SUMMARY_FILE_NAME} -c 'print(max(p[0] for p in q("select $memory_usage_gpu.max").fetchall()))' | grep -v INFO)
    TIMING_ARCH=$(uname -m)

    # --- Create a YAML-compatible text snippet with the timing info
    rm -f ${YAML_OUTPUT_NAME}
    printf "Creating YAML output: ${YAML_OUTPUT_NAME}\n"
    printf "run_date: ${formatted_timestamp}\nrun_host: Lassen\n" > ${YAML_OUTPUT_NAME}
    printf "cl_device: ${CL_DEVICE}\n" >> ${YAML_OUTPUT_NAME}
    printf "num_processors: ${nproc}\n" >> ${YAML_OUTPUT_NAME}
    printf "run_arch: ${TIMING_ARCH}\ngpu_arch: GV100GL\n" >> ${YAML_OUTPUT_NAME}
    printf "mirge_version: 70c1a6aa77a0d199104820a9b190e0a7aa5c0b81\n" >> ${YAML_OUTPUT_NAME}
    printf "driver_version: fb778f46cc5b2a889f9fcbbb8396224297d64cea\n" >> ${YAML_OUTPUT_NAME}
    printf "time_startup: ${STARTUP_TIME}\ntime_first_step: ${FIRST_STEP}\n" >> ${YAML_OUTPUT_NAME}
    printf "time_first_10: ${FIRST_10_STEPS}\ntime_second_10: ${SECOND_10_STEPS}\n" >> ${YAML_OUTPUT_NAME}
    printf "max_python_mem_usage: ${MAX_PYTHON_MEM_USAGE}\n" >> ${YAML_OUTPUT_NAME}
    printf "max_gpu_mem_usage: ${MAX_GPU_MEM_USAGE}\n---\n" >> ${YAML_OUTPUT_NAME}

    cat ${YAML_OUTPUT_NAME} >> ${MAIN_YAML_FILE_NAME}
    rm -f ${YAML_OUTPUT_NAME}

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
process_file=${1:-""}
if [[ ! -z "${process_file}" ]]; then
    printf "Processing single file: ${process_file}\n"
    timestamp=$(printf "${process_file}" | sed -e 's/.*-\([0-9]\{8\}-[0-9]\{6\}\)\.sqlite/\1/')
    printf "Timestamp: ${timestamp}\n"
    process_parallel_runlog ${timestamp}
    return_code=$?
    conda deactivate
    exit ${return_code}
fi

# This bit just checks the timestamp of the latest file in cwd and
# then grabs any data from the data source that is newer.
last_processed_timestamp=$(date -d "yesterday 24 hours ago" +"%Y-%m-%d %H:%M")
last_date="0"      # $(date -d "yesterday 24 hours ago" +"%s")
for timestamp in $(ls *-timing-data-*.sqlite | sed -e 's/.*-\([0-9]\{8\}-[0-9]\{6\}\)\.sqlite/\1/' | sort -u)
do
    data_date=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" +'%s')
    if [ ${data_date} -gt ${last_date} ]; then
        last_date=${data_date}
    fi
done
last_processed_timestamp=$(date -d "@${last_date}" +"%Y-%m-%d %H:%M") 
printf "Processing any data later than ${last_processed_timestamp}\n"

ln -sf ${SQL_DATA_SOURCE_DIR}/*-rank0-*.sqlite .

for timestamp in $(ls *-rank0-*.sqlite | sed -e 's/.*-\([0-9]\{8\}-[0-9]\{6\}\)\.sqlite/\1/' | sort -u)
do
    data_date=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" +'%s')
    if [ ${data_date} -gt ${last_date} ]; then
        printf "Processing timestamp: ${timestamp}\n"
        process_parallel_runlog ${timestamp}
    fi
done

rm *-rank0-*sqlite

conda deactivate
