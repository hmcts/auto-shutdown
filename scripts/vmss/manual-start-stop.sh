#!/usr/bin/env bash

# Script that allows users to manual start environments via GitHub workflows and accepts inputs from the workflow

# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vmss/common-functions.sh
source scripts/common/common-functions.sh

# Check and set default MODE if not provided
MODE=${1:-start}

# Convert "stop" to "deallocate"
if [[ "$MODE" == "stop" ]]; then
    MODE="deallocate"
fi

# Validate MODE
if [[ "$MODE" != "start" && "$MODE" != "deallocate" ]]; then
    echo "Invalid MODE. Please use 'start' or 'deallocate'."
    exit 1
fi

# Ensure environment and area are set
if [[ -z "$SELECTED_ENV" || -z "$SELECTED_AREA" ]]; then
    echo "Environment or Area not set. Please check your configuration." >&2
    exit 1
fi

# Map environment name to Azure-friendly tag
case "$SELECTED_ENV" in
    "AAT / Staging") vm_env="staging" ;;
    "Preview / Dev") vm_env="development" ;;
    "Test / Perftest") vm_env="testing" ;;
    "PTL") vm_env="production" ;;
    "PTLSBOX") vm_env="sandbox" ;;
    *) vm_env=$(to_lowercase "$SELECTED_ENV") ;;
esac

# Map business area if necessary
vmss_business_area="$SELECTED_AREA"
if [[ "$vmss_business_area" == "SDS" ]]; then
    vmss_business_area="Cross-Cutting"
fi

# Retrieve VMSS based on environment and area
VMSS_LIST=$(get_vmss "$vm_env" "$vmss_business_area")
vmss_count=$(jq -c -r '.count' <<<$VMSS_LIST)

if [[ $vmss_count -eq 0 ]]; then
    echo "No VM Scale Sets found for environment: $vm_env and area: $vmss_business_area." >&2
    exit 1
fi

# Iterate over VMSS
jq -c '.data[]' <<<$VMSS_LIST | while read vmss; do

    # Retrieve VMSS details
    get_vmss_details "$vmss"

    ts_echo_color BLUE "Processing VMSS: $VMSS_NAME, RG: $RESOURCE_GROUP, SUB: $SUBSCRIPTION"

    if [[ $DEV_ENV != "true" ]]; then
        vmss_state_messages
        az vmss $MODE --name $VMSS_NAME --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on vmss
    else
        ts_echo_color BLUE "Development Env: simulating state commands only."
        vmss_state_messages
    fi

    # Get VMSS power state after operation
    new_state=$(get_vmss_by_id $VMSS_ID | jq -cr '.powerState | split("/")[1]')
    ts_echo "VM Scale Set: $VMSS_NAME is in state: $new_state"

done