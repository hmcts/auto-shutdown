#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/bastion/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
MODE=${1:-start}
SKIP="false"

# Check if MODE is stop and set to deallocate
if [[ $MODE == "stop" ]]; then
    MODE="deallocate"
fi

# Catch problems with MODE input, must be one of Start/Stop
if [[ "$MODE" != "start" && "$MODE" != "deallocate" ]]; then
    echo "Invalid MODE. Please use 'start' or 'deallocate'."
    exit 1
fi

# Convert the second argument to lowercase
env_name=$(echo "$2" | tr '[:upper:]' '[:lower:]')

# Map the supplied environment name to the matching Bastion host environment.
# Also creates a list of environments that a Bastion is assigned to.
case "$env_name" in
    "production")
        bastionEnv="production"
        supportedEnvs=("Production" "PTL")
        ;;
    "staging")
        bastionEnv="staging"
        supportedEnvs=("AAT / Staging" "Preview / Dev" "Test / Perftest" "ITHC" "Demo")
        ;;
    "sandbox")
        bastionEnv="sandbox"
        supportedEnvs=("Sandbox" "PTLSbox")
        ;;
    *)
        echo "Invalid environment name."
        exit 1
        ;;
esac

# Convert the array to a JSON list for later use
# This list contains all the environments that a Bastion is assigned to
# e.g. Non-Prod is assigned to many environments so we list them all here if this script was run for Non-Prod
supportedEnvs=$(printf '%s\n' "${supportedEnvs[@]}" | jq -R . | jq -s .)

BASTIONS=$(get_bastions "$bastionEnv")
bastion_count=$(jq -c -r '.count' <<<$BASTIONS)
log "$bastion_count VM's found for $bastionEnv bastion environment"
log "----------------------------------------------"

# For each VM found in the function `get_vms` start another loop
jq -c '.data[]' <<<$BASTIONS | while read bastion; do
    # Function that returns the Resource Group, Id and Name of the Bastion and its current state as variables
    get_bastion_details

    log "====================================================="
    log "Processing Bastion: $VM_NAME in Resource Group: $RESOURCE_GROUP"
    log "====================================================="

    # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value based
    # on a tag named `startupMode` and the `issues_list.json` file which contains user requests to keep environments online after normal hours
    # We supply the JSON formatted supportedEnvs variable here.
    log "checking skip logic for env: "$env_name", business_area: $BUSINESS_AREA, mode: $MODE"
    SKIP=$(should_skip_start_stop "$supportedEnvs" $BUSINESS_AREA $MODE "bastion")
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
