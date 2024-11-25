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
        application_gateway_env="staging"
        ;;
    "Preview / Dev")
        application_gateway_env="development"
        ;;
    "Test / Perftest")
        application_gateway_env="testing"
        ;;
    "PTL")
        application_gateway_env="production"
        ;;
    "PTLSBOX")
        application_gateway_env="sandbox"
        ;;
    *)
        application_gateway_env=$(to_lowercase "$SELECTED_ENV")
        ;;
esac

# Map the app gateway area if necessary
application_gateway_business_area="$SELECTED_AREA"
if [[ "$application_gateway_business_area" == "SDS" ]]; then
    application_gateway_business_area="Cross-Cutting"
fi

# Retrieve application gateway's based on environment and area
APPLICATION_GATEWAYS=$(get_application_gateways "$application_gateway_env" "$application_gateway_business_area")
application_gateway_count=$(jq -c -r '.count' <<<$APPLICATION_GATEWAYS)
if [[ $application_gateway_count -eq 0 ]]; then
    echo "No clusters found for environment: $application_gateway_env and area: $application_gateway_business_area." >&2
    exit 1
fi


# Loop over the discovered App Gateways to start / stop each
# For each App Gateway found in the function `get_application_gateways` start another loop
jq -c '.data[]' <<<$APPLICATION_GATEWAYS | while read application_gateway; do

	# Function that returns the Resource Group, Id and Name of the Application Gateway and its current state as variables
    get_application_gateways_details

	ts_echo_color BLUE "Processing App Gateway: $APPLICATION_GATEWAY_NAME, RG: $RESOURCE_GROUP, SUB: $SUBSCRIPTION"

    # If SKIP is false then we progress with the action (stop/start) for the particular App Gateway in this loop run, if not skip and print message to the logs
    if [[ $DEV_ENV != "true" ]]; then
    	appgateway_state_messages
    	az network application-gateway $MODE --resource-group $RESOURCE_GROUP --name $APPLICATION_GATEWAY_NAME --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on application_gateway
    else
        ts_echo_color BLUE "Development Env: simulating state commands only."
        appgateway_state_messages
    fi

	# Get the app gateway state after the operation
    RESULT=$(az aks show --name "$APPLICATION_GATEWAY_NAME" -g "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION" | jq -r .properties_operationalState)
    ts_echo "Cluster $CLUSTER_NAME is in state: $RESULT"
done





