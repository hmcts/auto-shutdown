#!/usr/bin/env bash

# Script that allows users to manual start environments via GitHub workflows and accepts inputs from the workflow

# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/mysql-flexible/common-functions.sh
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
        mysql_server_env="staging"
        ;;
    "Preview / Dev")
        mysql_server_env="development"
        ;;
    "Test / Perftest")
        mysql_server_env="testing"
        ;;
    "PTL")
        mysql_server_env="production"
        ;;
    "PTLSBOX")
        mysql_server_env="sandbox"
        ;;
    *)
        mysql_server_env=$(to_lowercase "$SELECTED_ENV")
        ;;
esac

# Map the MySQL Flexible Server area if necessary
mysql_server_business_area="$SELECTED_AREA"
if [[ "$mysql_server_business_area" == "SDS" ]]; then
    mysql_server_business_area="Cross-Cutting"
fi

# Retrieve MySQL Flexible Servers based on environment and area
MYSQL_SERVERS=$(get_mysql_servers "$mysql_server_env" "$mysql_server_business_area")
mysql_server_count=$(jq -c -r '.count' <<<$MYSQL_SERVERS)
if [[ $mysql_server_count -eq 0 ]]; then
    echo "No MySQL flexible servers found for environment: $mysql_server_env and area: $mysql_server_business_area." >&2
    exit 1
fi


jq -c '.data[]' <<<$MYSQL_SERVERS | while read mysqlserver; do

	# Function that returns the Resource Group, Id and Name of the MySQL Flexible Server and its current state as variables
    get_mysql_server_details

	ts_echo_color BLUE "Processing MySQL Flexible Server: $SERVER_NAME, RG: $RESOURCE_GROUP, SUB: $SUBSCRIPTION"

    # If SKIP is false then we progress with the action (stop/start) for the particular MySQL Flexible Server in this loop run, if not skip and print message to the logs
    if [[ $DEV_ENV != "true" ]]; then
    	mysql_server_state_messages
    	az mysql flexible-server $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on mysql flexible server
    else
        ts_echo_color BLUE "Development Env: simulating state commands only."
        mysql_server_state_messages
    fi

	# Get the mysql flexible server state after the operation
    RESULT=$(az mysql flexible-server show --name "$SERVER_NAME" -g "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION" | jq -r .state)
    ts_echo "MySQL Flexible Server: $SERVER_NAME is in state: $RESULT"
done
