#!/usr/bin/env bash

# Script that allows users to manual start environments via GitHub workflows and accepts inputs from the workflow

# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/bastion/common-functions.sh
source scripts/common/common-functions.sh

# Check and set default MODE if not provided
MODE=${1:-start}

# Check if MODE is stop and set to deallocate
if [[ $MODE == "stop" ]]; then
    MODE="deallocate"
fi

# Ensure valid MODE
# Catch problems with MODE input, must be one of Start/Stop
if [[ "$MODE" != "start" && "$MODE" != "deallocate" ]]; then
    echo "Invalid MODE. Please use 'start' or 'deallocate'."
    exit 1
fi

# Ensure SELECTED_ENV is set
if [[ -z "$SELECTED_ENV" ]]; then
    echo "Environment not set. Please check your configuration." >&2
    exit 1
fi

# Map the environment name to match Azure enviornment tag
case "$SELECTED_ENV" in
    "PTL")
        vm_env="production"
        ;;
    "AAT / Staging")
        vm_env="staging"
        ;;
    "Preview / Dev")
        vm_env="staging"
        ;;
    "Test / Perftest")
        vm_env="staging"
        ;;
    "ITHC")
        vm_env="staging"
        ;;
    "Demo")
        vm_env="staging"
        ;;
    "Sandbox")
        vm_env="sandbox"
        ;;
    "PTLSBOX")
        vm_env="sandbox"
        ;;
    *)
        echo "Invalid SELECTED_ENV: $SELECTED_ENV" >&2
        exit 1
        ;;
esac

# Retrieve Virtual Machines based on environment
BASTIONS=$(get_bastion "$vm_env")
bastion_count=$(jq -c -r '.count' <<<$BASTIONS)
if [[ $bastion_count -lt 1 ]]; then
    echo "No Bastion found for environment: $vm_env." >&2
    exit 1
fi

jq -c '.data[]' <<<$BASTIONS | while read vm; do

	# Function that returns the Resource Group, Id and Name of the VM and its current state as variables
    get_vm_details

    # Remove SecOps bastions from list
    if [[ $VM_NAME != **"secops"** ]]; then
        ts_echo_color BLUE "Processing VM: $VM_NAME, RG: $RESOURCE_GROUP, SUB: $SUBSCRIPTION"

        # If SKIP is false then we progress with the action (stop/start) for the particular VM in this loop run, if not skip and print message to the logs
        if [[ $DEV_ENV != "true" ]]; then
            vm_state_messages
            az vm $MODE --ids $VM_ID --no-wait || echo Ignoring any errors while $MODE operation on vm
        else
            ts_echo_color BLUE "Development Env: simulating state commands only."
            vm_state_messages
        fi

        # Get the VM state after the operation
        RESULT=$(az graph query -q "resources
        | where ['id'] == '$VM_ID'
        | project properties" -o json | jq -r '.data[0].properties.extended.instanceView.powerState.code')

        ts_echo "Virtual Machine: $VM_NAME is in state: $RESULT"
    else
        ts_echo_color BLUE "Skipping Bastion as it belongs to SecOps: $VM_NAME"
    fi
done
