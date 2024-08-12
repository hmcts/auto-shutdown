#!/bin/bash
source scripts/common/common-functions.sh

ts_echo_color RED "Beginning of log file"
echo "----------------------------------------------"

cat scripts/common/log.txt

echo "----------------------------------------------"
ts_echo_color RED "End of log file"