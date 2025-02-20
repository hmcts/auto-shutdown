#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vmss/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
MODE=${1:-start}
SKIP="false"

# Catch problems with MODE input, must be one of Start/Stop
if [[ "$MODE" != "start" && "$MODE" != "deallocate" ]]; then
    echo "Invalid MODE. Please use 'start' or 'deallocate'."
    exit 1
fi

VMS=$(get_vmss "$2")
vm_count=$(jq -c -r '.count' <<<$VMS)
log "$vmss_count VMSS's found"
log "----------------------------------------------"