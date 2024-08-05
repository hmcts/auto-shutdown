#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/sqlmi/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
MODE=${1:-start}
SKIP="false"

# Catch problems with MODE input, must be one of Start/Stop
if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

# Find all subscriptions that are available to the credential used and saved to SUBSCRIPTIONS variable
SUBSCRIPTIONS=$(az account list -o json)

# For each subscription found, start the loop
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do

    # Function that returns the Subscription Id and Name as variables,
    # sets the subscription as the default then returns a json formatted variable of available Managed SQL Instances with an autoshutdown tag
    get_sql_mi_servers
    echo "Scanning $SUBSCRIPTION_NAME..."

    # For each App Gateway found in the function `get_sql_mi_servers` start another loop
    jq -c '.[]' <<< $MI_SQL_SERVERS | while read server; do

        # Function that returns the Resource Group, Id and Name of the Managed SQL Instances and its current state as variables
        get_sql_mi_server_details

        # Set variables based on inputs which are used to decide when to SKIP an environment
        managed_instance_env=${ENVIRONMENT/stg/Staging}
        managed_instance_business_area=${BUSINESS_AREA/ss/cross-cutting}

        # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value
        # based on the issues_list.json file which contains user requests to keep environments online after normal hours
        SKIP=$(should_skip_start_stop $managed_instance_env $managed_instance_business_area $MODE)

        # If SKIP is false then we progress with the action (stop/start) for the particular Managed SQL Instance in this loop run, if not skip and print message to the logs
        if [[ $SKIP == "false" ]]; then
            ts_echo_color GREEN "About to run $MODE operation on sql server $SERVER_NAME (rg:$RESOURCE_GROUP)"
            ts_echo_color GREEN "Command to run: az sql mi $MODE --resource-group $RESOURCE_GROUP --mi $SERVER_NAME --no-wait || echo Ignoring any errors while $MODE operation on sql server"
            az sql mi $MODE --resource-group $RESOURCE_GROUP --mi $SERVER_NAME --no-wait || echo Ignoring any errors while $MODE operation on sql server
        else
            ts_echo_color AMBER "SQL server $SERVER_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
        fi
    done
done
