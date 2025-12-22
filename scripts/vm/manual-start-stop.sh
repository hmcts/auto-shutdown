#!/usr/bin/env bash

# Script that allows users to manual start environments via GitHub workflows and accepts inputs from the workflow

# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vm/common-functions.sh
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

# Ensure SELECTED_ENV and SELECTED_AREA are set
if [[ -z "$SELECTED_ENV" || -z "$SELECTED_AREA" ]]; then
    echo "Environment or Area not set. Please check your configuration." >&2
    exit 1
fi

# Map the environment name to match Azure enviornment tag
case "$SELECTED_ENV" in
    "AAT / Staging")
        vm_env="staging"
        ;;
    "Preview / Dev")
        vm_env="development"
        ;;
    "Test / Perftest")
        vm_env="testing"
        ;;
    "PTL")
        vm_env="production"
        ;;
    "PTLSBOX")
        vm_env="sandbox"
        ;;
    *)
        vm_env=$(to_lowercase "$SELECTED_ENV")
        ;;
esac

# Map the VM area if necessary
vm_business_area="$SELECTED_AREA"
if [[ "$vm_business_area" == "SDS" ]]; then
    vm_business_area="Cross-Cutting"
fi

# Retrieve Virtual Machines based on environment and area
VMS=$(get_vms "$vm_env" "$vm_business_area")
vm_count=$(jq -c -r '.count' <<<$VMS)
if [[ $vm_count -eq 0 ]]; then
    echo "No VMs found for environment: $vm_env and area: $vm_business_area." >&2
    exit 0
fi


jq -c '.data[]' <<<$VMS | while read vm; do

	# Function that returns the Resource Group, Id and Name of the VM and its current state as variables
    get_vm_details

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

done