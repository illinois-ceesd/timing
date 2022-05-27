#!/bin/bash

dir_name=$1
todays_date=$(date "+%Y.%m.%d")
printf "Today's date: ${todays_date}\n"
search_pattern="${dir_name}/*${todays_date}*sqlite"
if ls $search_pattern 1> /dev/null 2>&1; then
    echo "Found today's data."
    exit 0
fi
echo "Today's data not found."
exit 1
