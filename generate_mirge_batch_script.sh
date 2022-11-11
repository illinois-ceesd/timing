#!/bin/bash

nnodes="1"
time_limit="120"
command_script=""
finish_filename="mirge-batch-finished"
output_script_name="mirge-batch-script.sh"
queue_name="pdebug"
emirge_home="."
execute_batch_script=""

while getopts n:c:t:o:q:e:x: flag
do
    case "${flag}" in
        n) nnodes=${OPTARG};;
        c) command_script=${OPTARG};;
        t) time_limit=${OPTARG};;
        o) output_script_name=${OPTARG};;
        q) queue_name=${OPTARG};;
        x) execute_batch_script=${OPTARG};;
        e) emirge_home=${OPTARG};;
    esac
done

echo "Number of Nodes: $nnodes";
echo "Time Limit: $time_limit";
echo "Command script: $command_script";
echo "Output script: $output_script_name";
echo "Queue: ${queue_name}";
echo "Emirge home: ${emirge_home}";

BATCH_SCRIPT_NAME="${output_script_name}"
TIMING_HOST=$(hostname)
rm -f ${finish_filename}
return_code=0

case $TIMING_HOST in

    # --- Run the timing test in a batch job on Lassen@LLC
    lassen*)
        echo "Resolved Host: Lassen"
        TIMING_HOST="Lassen"
        # GPU_ARCH="GV100GL"
        # BATCH_SCRIPT_NAME="${exename}_timing_job.sh"
        rm -f ${BATCH_SCRIPT_NAME}
        # ---- Generate a batch script for running a job
        cat <<EOF > ${BATCH_SCRIPT_NAME}
#!/bin/bash

#BSUB -nnodes ${nnodes}
#BSUB -G uiuc
#BSUB -W ${time_limit}
#BSUB -q ${queue_name}

printf "Running with EMIRGE_HOME=${emirge_home}\n"

source ${emirge_home}/config/activate_env.sh
export PYOPENCL_CTX="port:tesla"
export XDG_CACHE_HOME="/tmp/$USER/xdg-scratch"
export POCL_CACHE_DIR_ROOT="/tmp/$USER/pocl-cache"
unset CONDA_CACHE_DISABLE

rm -rf \$XDG_CACHE_HOME
rm -f ${finish_filename}

which python
conda env list
env
env | grep LSB_MCPU_HOSTS

date
# --- User's commands go here ----
# example:
# jsrun -g 1 -a 1 -n 16 bash -c 'POCL_CACHE_DIR=$POCL_CACHE_DIR_ROOT/$$ python -u -m mpi4py ./${exename}.py -i run_params.yaml --log --lazy'
return_code=0
if [[ ! -z "${command_script}" ]]; then
   . ${command_script}
   return_code=\$?
fi
# --------------------------------
date
touch ${finish_filename}
return \$return_code
EOF
        chmod +x ${BATCH_SCRIPT_NAME}
        # ---- Submit the batch script and wait for the job to finish
        if [[ ! -z "${execute_batch_script}" ]]; then
            bsub ${BATCH_SCRIPT_NAME}
            # ---- Wait 10 minutes right off the bat (the job is at least 10 min)
            sleep 600
            iwait=0
            while [ ! -f "./${finish_filename}" ]; do 
                iwait=$((iwait+1))
                if [ "$iwait" -gt 360 ]; then # give up after 1 hour
                    printf "Timed out waiting on batch job.\n"
                    exit 1 # skip the rest of the script
                fi
                sleep 20
            done
            sleep 30  # give the batch system time to spew its junk into the log
        fi
        ;;

    # --- Run the timing test on an unknown/generic machine 
    *)
        printf "Host: Unknown\n"
        rm -f ${BATCH_SCRIPT_NAME}
        # ---- Generate a batch script for running a job
        cat <<EOF > ${BATCH_SCRIPT_NAME}
#!/bin/bash

printf "Running with EMIRGE_HOME=${emirge_home}\n"

source "${emirge_home}/config/activate_env.sh"
export PYOPENCL_CTX="port:pthread"
export PYOPENCL_TEST="port:pthread"
export XDG_CACHE_HOME="/tmp/$USER/xdg-scratch"
export POCL_CACHE_DIR_ROOT="/tmp/$USER/pocl-cache"
unset CONDA_CACHE_DISABLE

rm -rf \$XDG_CACHE_HOME
rm -f ${finish_filename}

which python
conda env list
env

date
return_code=0
# --- User's commands go here ----
# jsrun -g 1 -a 1 -n 16 bash -c 'POCL_CACHE_DIR=$POCL_CACHE_DIR_ROOT/$$ python -u -m mpi4py ./${exename}.py -i run_params.yaml --log --lazy'
if [[ -z "${command_script}" ]]; then
   . ${command_script}
   return_code=\$?
fi
# --------------------------------
date
touch ${finish_filename}
return \$return_code
EOF
        chmod +x ${BATCH_SCRIPT_NAME}
        # PYOPENCL_TEST=port:pthread python -O -m mpi4py ./${exename}.py -i timing_params.yaml ${EXEOPTS}
        if [[ ! -z "${execute_batch_script}" ]]; then
            . ${BATCH_SCRIPT_NAME}
            return_code=$?
        fi
        ;;
esac

return $return_code

date
