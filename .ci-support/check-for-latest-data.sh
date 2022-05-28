#!/bin/bash

dir_name=$1
testing_date=$(cat latest_testing_date)
printf "Today's date: ${testing_date}\n"
search_pattern="${dir_name}/*${testing_date}*sqlite"
if ls $search_pattern 1> /dev/null 2>&1; then
    echo "Found timing data for latest tests."
    exit 0
fi
echo "Timing data for latest tests not found."
exit 1
