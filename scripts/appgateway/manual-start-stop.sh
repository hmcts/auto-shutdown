#!/usr/bin/env bash

# Script that allows users to manual start environments via GitHub workflows and accepts inputs from the workflow

# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/appgateway/common-functions.sh
source scripts/common/common-functions.sh

# Check and set default MODE if not provided
MODE=${1:-start}

# Ensure valid MODE
if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'." >&2
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
        appgateway_env="staging"
        ;;
    "Preview / Dev")
        appgateway_env="development"
        ;;
    "Test / Perftest")
        appgateway_env="testing"
        ;;
    "PTL")
        appgateway_env="production"
        ;;
    "PTLSBOX")
        appgateway_env="sandbox"
        ;;
    *)
        appgateway_env=$(to_lowercase "$SELECTED_ENV")
        ;;
esac

# Map the appgateway area if necessary
appgateway_area="$SELECTED_AREA"
if [[ "$appgateway_area" == "SDS" ]]; then
    appgateway_area="Cross-Cutting"
fi

# Retrieve AppGateway based on environment and area
APPLICATION_GATEWAYS=$(get_application_gateways "$appgateway_env" "$appgateway_area")
appgateway_count=$(jq -c -r '.count' <<<$APPLICATION_GATEWAYS)
if [[ $appgateway_count -eq 0 ]]; then
    echo "No application gateways found for environment: $appgateway_env and area: $appgateway_area." >&2
    exit 1
fi

# Loop over the discovered App Gateways to start each
jq -c '.data[]'<<< $APPLICATION_GATEWAYS | while read -r application_gateway; do
	
	# Function that returns the Resource Group, Id and Name of the Application Gateway and its current state as variables
	get_application_gateways_details

	log "================================================================================"
    log "Processing Cluster: $APPLICATION_GATEWAY_NAME, RG: $RESOURCE_GROUP, SUB: $SUBSCRIPTION"
    log "================================================================================"
	
	if [[ $DEV_ENV != "true" ]]; then
        appgateway_state_messages
        az network application-gateway $MODE --resource-group $RESOURCE_GROUP --name $APPLICATION_GATEWAY_NAME --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on application_gateway
    else
        ts_echo_color BLUE "Development Env: simulating state commands only."
        appgateway_state_messages
    fi

	# Get the AppGateway state after the operation
    RESULT=$(az network application-gateway show --name "$APPLICATION_GATEWAY_NAME" -g "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION" | jq -r .operationalState)
    ts_echo "Application Gateway: $APPLICATION_GATEWAY_NAME is in state: $RESULT"
done
