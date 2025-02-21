#!/usr/bin/env bash

# Script that allows users to manually start environments via GitHub workflows and accepts inputs from the workflow

# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vmss/common-functions.sh
source scripts/common/common-functions.sh

# Check and set default MODE if not provided
MODE=${1:-start}

# Check if MODE is stop and set to deallocate
if [[ $MODE == "stop" ]]; then
    MODE="deallocate"
fi

# Ensure valid MODE
if [[ "$MODE" != "start" && "$MODE" != "deallocate" ]]; then
    echo "Invalid MODE. Please use 'start' or 'deallocate'."
    exit 1
fi

# Ensure SELECTED_ENV and SELECTED_AREA are set
if [[ -z "$SELECTED_ENV" || -z "$SELECTED_AREA" ]]; then
    echo "Environment or Area not set. Please check your configuration." >&2
    exit 1
fi

# Map the environment name to match Azure environment tag
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


    # Get the VMSS instance state after the operation
    RESULT=$(az graph query -q "resources 
    | where ['id'] == '$VMSS_ID' 
    | project properties.extended.instanceView.powerState.code" -o json | jq -r '.data[0].properties.extended.instanceView.powerState.code')

    ts_echo "VMSS Instance: $INSTANCE_ID in Scale Set: $VMSS_NAME is in state: $RESULT"

done
