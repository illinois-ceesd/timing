#!/bin/bash

dir_name=$1
date_offset=${2:-0}
testing_date=$(cat latest_testing_date)
tdf=${testing_date//./-}
if date --version >/dev/null 2>&1; then
    test_date=$(date -d"$tdf -${date_offset} days" +%Y.%m.%d)
else
    test_date=$(date -j -v-${date_offset}d -f "%Y-%m-%d" "${tdf}" "+%Y.%m.%d")
fi
printf "Tests ran on: ${testing_date}\n"
printf "Checking for timing data from: ${test_date}\n"
search_pattern="${dir_name}/*${test_date}*sqlite"
if ls $search_pattern 1> /dev/null 2>&1; then
    echo "Found timing data for latest tests."
    exit 0
fi
echo "Timing data for latest tests not found."
exit 1
