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

VMSS=$(get_vmss "$2")
vm_count=$(jq -c -r '.count' <<<$VMSS)
log "$vmss_count VMSS's found"
log "----------------------------------------------"

# For each VMSS found in the function `get_vmss` start another loop
jq -c '.data[]' <<<$VMSS | while read vmss; do
    # Function that returns the Resource Group, Id and Name of the VMSSs and its current state as variables
    get_vm_details

    log "====================================================="
    log "Processing Virtual Machine: $VM_NAME in Resource Group: $RESOURCE_GROUP"
    log "====================================================="