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

# Map the appgateway area if necessary
flexible_server_area="$SELECTED_AREA"
if [[ "$flexible_server_area" == "SDS" ]]; then
    flexible_server_area="Cross-Cutting"
fi

FLEXIBLE_SERVERS=$(get_flexible_sql_servers "$flexible_server_env" "$flexible_server_area")
flexible_server_count=$(jq -c -r '.count' <<< $FLEXIBLE_SERVERS)
if [[ $flexible_server_count -eq 0 ]]; then
    echo "No Flexible Servers found for environment: $flexible_server_env and area: $flexible_server_area." >&2
    exit 1
fi

# For each PostgreSQL Flexible Server returned from the az graph query start another loop
jq -c '.data[]' <<<$FLEXIBLE_SERVERS | while read flexibleserver; do

    # Function that returns details of the PostgreSQL Flexible Server json output.
    get_flexible_sql_server_details

	log "====================================================="
	log "Processing Flexible Server: $SERVER_NAME"
	log "====================================================="

    if [[ $DEV_ENV != "true" ]]; then
        flexible_server_state_messages
        az postgres flexible-server $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on sql server
    else
        ts_echo_color BLUE "Development Env: simulating state commands only."
        flexible_server_state_messages
    fi

	# Get the AppGateway state after the operation
    GRAPH_RESULT=$(az graph query -q "resources | where type =~ 'microsoft.dbforpostgresql/flexibleservers' | where name == '$SERVER_NAME' | where resourceGroup == '$RESOURCE_GROUP' | project properties.state" -o json)
	RESULT=$(jq -r '.data[].properties_state' <<< $GRAPH_RESULT)
    ts_echo "Application Gateway: $SERVER_NAME is in state: $RESULT"
done
