#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/flexible-server/common-functions.sh
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

    # Function that returns the Subscription Id and Name as variables, sets the subscription as
    # the default then returns a json formatted variable of available App Gateways with an autoshutdown tag
    get_subscription_flexible_sql_servers
    echo "Scanning $SUBSCRIPTION_NAME..."

    # For each App Gateway found in the function `get_subscription_flexible_sql_servers` start another loop
    jq -c '.[]' <<< $FLEXIBLE_SERVERS | while read flexibleserver; do

        # Function that returns the Resource Group, Id and Name of the Flexible SQL Server and its current state as variables
        get_flexible_sql_server_details

        # Set variables based on inputs which are used to decide when to SKIP an environment
        flexible_server_env=${ENVIRONMENT/stg/Staging}
        flexible_server_business_area=${BUSINESS_AREA/ss/cross-cutting}

        # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value
        # based on the issues_list.json file which contains user requests to keep environments online after normal hours
        SKIP=$(should_skip_start_stop $server_env $server_business_area $MODE)

        # If SKIP is false then we progress with the action (stop/start) for the particular App Gateway in this loop run, if not skip and print message to the logs
        if [[ $SKIP == "false" ]]; then
            ts_echo_color GREEN "About to run $MODE operation on flexible sql server $SERVER_NAME Resource Group: $RESOURCE_GROUP"
            ts_echo_color GREEN "Command to run: az postgres flexible sql server $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --no-wait || echo Ignoring any errors while $MODE operation on sql server"
            #simulation
            #az postgres flexible-server $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --no-wait || echo Ignoring any errors while $MODE operation on sql server
        else
            ts_echo_color AMBER "SQL server $SERVER_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
        fi
    done
done
