#!/bin/bash

cd y3-prediction-testing
cd scalability_test

job1=$(bsub scal1node_lassen.bsub.sh)
job1_id=$(printf "${job1}" | cut -d "<" -f 2 | cut -d ">" -f 1)
job2=$(bsub -w ${job1_id} scal2nodes_lassen.bsub.sh)
job2_id=$(printf "${job2}" | cut -d "<" -f 2 | cut -d ">" -f 1)
job3=$(bsub -w ${job2_id} scal4nodes_lassen.bsub.sh)
job3_id=$(printf "${job3}" | cut -d "<" -f 2 | cut -d ">" -f 1)
printf "Scaling JobIDs: ${job1_id} ${job2_id} ${job3_id}\n"

cd ../..
