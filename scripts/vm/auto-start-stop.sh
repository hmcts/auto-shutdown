#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vm/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
MODE=${1:-start}
SKIP="false"

# Catch problems with MODE input, must be one of Start/Stop
if [[ "$MODE" != "start" && "$MODE" != "deallocate" ]]; then
    echo "Invalid MODE. Please use 'start' or 'deallocate'."
    exit 1
fi

VMS=$(get_vms "$2")
vm_count=$(jq -c -r '.count' <<<$VMS)
log "$vm_count VM's found"
log "----------------------------------------------"

# For each VM found in the function `get_vms` start another loop
jq -c '.data[]' <<<$VMS | while read vm; do
    # Function that returns the Resource Group, Id and Name of the VMs and its current state as variables
    get_vm_details

    log "====================================================="
    log "Processing Virtual Machine: $VM_NAME in Resource Group: $RESOURCE_GROUP"
    log "====================================================="

    if [[ $ENVIRONMENT == "development" ]]; then
        VM_ENV=${ENVIRONMENT/development/Preview}
    elif [[ $ENVIRONMENT == "testing" ]]; then
        VM_ENV=${ENVIRONMENT/testing/Perftest}
    else
        VM_ENV=$(to_lowercase "$ENVIRONMENT")
    fi

    # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value based
    # on a tag named `startupMode` and the `issues_list.json` file which contains user requests to keep environments online after normal hours
    log "checking skip logic for env: $VM_ENV, business_area: $BUSINESS_AREA, mode: $MODE"
    SKIP=$(should_skip_start_stop $VM_ENV $BUSINESS_AREA $MODE "vm" "$VM_NAME")
    log "SKIP evalulated to $SKIP"

    # If SKIP is false then we progress with the action (deallocate/start) for the particular VM in this loop run, if not skip and print message to the logs
    if [[ $SKIP == "false" ]]; then
        if [[ $DEV_ENV != "true" ]]; then
            vm_state_messages
            az vm $MODE --ids $VM_ID --no-wait || echo Ignoring any errors while $MODE operation on vm
        else
            ts_echo_color BLUE "Development Env: simulating state commands only."
            vm_state_messages
        fi
    else
        ts_echo_color AMBER "VM: $VM_NAME in Resource Group: $RESOURCE_GROUP has been skipped from today's $MODE operation schedule"
    fi
done
