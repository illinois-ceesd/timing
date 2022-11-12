#!/bin/bash

nnodes="1"
time_limit="120"
finish_filename="mirge-batch-finished"
batch_script_name="mirge-batch-script.sh"
queue_name="pdebug"
stdio_filename="mirge-batch-script-out.txt"
wait_duration="600"
working_directory="."

while getopts t:b:f:w:d: flag
do
    case "${flag}" in
        t) time_limit=${OPTARG};;
        b) batch_script_name=${OPTARG};;
        f) finish_filename=${OPTARG};;
        w) wait_duration=${OPTARG};;
        d) working_directory=${OPTARG};;
        o) stdio_filename=${OPTARG};;
    esac
done

echo "Time Limit: $time_limit";
echo "Batch script: $batch_script_name";
echo "Finish filename: ${finish_filename}";
echo "Working directory: ${working_directory}";
echo "Stdio filename: ${stdio_filename}";

BATCH_SCRIPT_NAME="${batch_script_name}"
BATCH_HOST=$(hostname)
rm -f ${finish_filename}
return_code=0

cd ${working_directory}

case $BATCH_HOST in

    # --- Run the batch job through the queue on Lassen@LLC
    lassen*)
        echo "Resolved Host: Lassen"
        BATCH_HOST="Lassen"
        date
        # ---- Submit the batch script and wait for the job to finish
        bsub ${BATCH_SCRIPT_NAME}
        sleep ${wait_duration}
        iwait=0
            while [ ! -f "${finish_filename}" ]; do 
                iwait=$((iwait+1))
                if [ "$iwait" -gt ${time_limit} ]; then # give up after a while
                    printf "Timed out waiting on batch job.\n"
                    exit 1 # skip the rest of the script
                fi
                sleep 60
            done
            sleep 30  # give the batch system time to spew its junk into the log
        fi
        ;;

    # --- Run the "batch job" on unknown/generic machine 
    *)
        printf "Host: Unknown\n"
        . ${BATCH_SCRIPT_NAME} >& ${stdio_filename}
        return_code=$?
        ;;
esac

date

cd -

return $return_code

