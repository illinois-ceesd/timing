#!/bin/bash

cd y3-prediction-testing
cd scalability_test

job1=$(bsub scal1node_lassen.bsub.sh)
job1_id=$(printf "${job1}" | cut -d "<" -f 2 | cut -d ">" -f 1)
job2=$(bsub -w ${job1_id} scal4nodes_lassen.bsub.sh)
job2_id=$(printf "${job2}" | cut -d "<" -f 2 | cut -d ">" -f 1)

printf "Scaling JobIDs: ${job1_id} ${job2_id}\n"

cd ../..
