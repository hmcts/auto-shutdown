#!/usr/bin/env bash

# Script that allows users to manual start environments via GitHub workflows and accepts inputs from the workflow

# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/flexible-server/common-functions.sh
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
        flexible_server_env="staging"
        ;;
    "Preview / Dev")
        flexible_server_env="development"
        ;;
    "Test / Perftest")
        flexible_server_env="testing"
        ;;
    "PTL")
        flexible_server_env="production"
        ;;
    "PTLSBOX")
        flexible_server_env="sandbox"
        ;;
    *)
        flexible_server_env=$(to_lowercase "$SELECTED_ENV")
        ;;
esac

# Map the Flexible Server area if necessary
flexible_server_business_area="$SELECTED_AREA"
if [[ "$flexible_server_business_area" == "SDS" ]]; then
    flexible_server_business_area="Cross-Cutting"
fi

# Retrieve Flexible Servers based on environment and area
FLEXIBLE_SERVERS=$(get_flexible_sql_servers "$flexible_server_env" "$flexible_server_business_area")
flexible_server_count=$(jq -c -r '.count' <<<$FLEXIBLE_SERVERS)
if [[ $flexible_server_count -eq 0 ]]; then
    echo "No clusters found for environment: $flexible_server_env and area: $flexible_server_business_area." >&2
    exit 1
fi


jq -c '.data[]' <<<$FLEXIBLE_SERVERS | while read flexibleserver; do

	# Function that returns the Resource Group, Id and Name of the Flexible Server and its current state as variables
    get_flexible_sql_server_details

	ts_echo_color BLUE "Processing Flexible Server: $SERVER_NAME, RG: $RESOURCE_GROUP, SUB: $SUBSCRIPTION"

    # If SKIP is false then we progress with the action (stop/start) for the particular Flexible Server in this loop run, if not skip and print message to the logs
    if [[ $DEV_ENV != "true" ]]; then
    	flexible_server_state_messages
    	az postgres flexible-server $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on flexible server
    else
        ts_echo_color BLUE "Development Env: simulating state commands only."
        flexible_server_state_messages
    fi

	# Get the app gateway state after the operation
    RESULT=$(az postgres flexible-server show --name "$SERVER_NAME" -g "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION" | jq -r .operationalState)
    ts_echo "Flexible Server: $SERVER_NAME is in state: $RESULT"
done
