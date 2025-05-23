#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vmss/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
MODE=${1:-start}
SKIP="false"

# Catch problems with MODE input, must be one of Start/Deallocate
if [[ "$MODE" != "start" && "$MODE" != "deallocate" ]]; then
    echo "Invalid MODE. Please use 'start' or 'deallocate'."
    exit 1
fi

VMSS=$(get_vmss "$2")
vmss_count=$(jq -c -r '.count' <<<$VMSS)
log "$vmss_count VMSS found"
log "----------------------------------------------"

# For each VMSS found in the function `get_vmss` start another loop
jq -c '.data[]' <<<$VMSS | while read vmss; do
    # Function that returns the Resource Group, Id and Name of the VMSS and its current state as variables
    get_vmss_details "$vmss"

    log "====================================================="
    log "Processing Virtual Machine Scale Set: $VMSS_NAME in Resource Group: $RESOURCE_GROUP"
    log "====================================================="

    if [[ $ENVIRONMENT == "development" ]]; then
        VMSS_ENV=${ENVIRONMENT/development/Preview}
    elif [[ $ENVIRONMENT == "testing" ]]; then
        VMSS_ENV=${ENVIRONMENT/testing/Perftest}
    else
        VMSS_ENV=$(to_lowercase "$ENVIRONMENT")
    fi

    # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value based
    # on a tag named `startupMode` and the `issues_list.json` file which contains user requests to keep environments online after normal hours
    log "checking skip logic for env: $VMSS_ENV, business_area: $BUSINESS_AREA, mode: $MODE"
    SKIP=$(should_skip_start_stop $VMSS_ENV $BUSINESS_AREA $MODE "vmss")
    log "SKIP evaluated to $SKIP"

    # If SKIP is false then we progress with the action (deallocate/start) for the particular VMSS in this loop run, if not skip and print message to the logs
    if [[ $SKIP == "false" ]]; then
        if [[ $DEV_ENV != "true" ]]; then
            vmss_state_messages
            az vmss $MODE --name $VMSS_NAME --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on vmss
        else
            ts_echo_color BLUE "Development Env: simulating state commands only."
            vmss_state_messages
        fi
    else
        ts_echo_color AMBER "VMSS: $VMSS_NAME in Resource Group: $RESOURCE_GROUP has been skipped from today's $MODE operation schedule"
    fi
done
