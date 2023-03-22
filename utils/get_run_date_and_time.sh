#!/bin/bash


get_run_time_and_date_from_sql_filename() {
    filename=$(basename -- "$1")
    filename="${filename%.*}"
    eman=$(printf "${filename}" | rev)
    r_time=`printf "${eman}" | cut -d "-" -f 1 | rev`
    r_date=`printf "${eman}" | cut -d "-" -f 2 | rev`
    printf "Time: ${r_time}\n"
    printf "Date: ${r_date}\n"
}

get_run_time_and_date_from_sql_filename $1
