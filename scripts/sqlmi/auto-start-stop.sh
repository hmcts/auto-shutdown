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

MI_SQL_SERVERS=$(get_sql_mi_servers "$2")
mi_sql_server_count=$(jq -c -r '.count' <<< $MI_SQL_SERVERS)
log "$mi_sql_server_count MI SQL Servers found"
log "----------------------------------------------"

# For each App Gateway found in the function `get_sql_mi_servers` start another loop
jq -c '.data[]' <<<$MI_SQL_SERVERS | while read server; do

    # Function that returns the Resource Group, Id and Name of the Managed SQL Instances and its current state as variables
    get_sql_mi_server_details

    # Set variables based on inputs which are used to decide when to SKIP an environment
    if [[ $ENVIRONMENT == "stg" ]]; then
        managed_instance_env=${ENVIRONMENT/stg/Staging}
    elif [[ $ENVIRONMENT == "sbox" ]]; then
        managed_instance_env=${ENVIRONMENT/sbox/Sandbox}
    else
        managed_instance_env=$ENVIRONMENT
    fi

    managed_instance_business_area=$BUSINESS_AREA

    # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value
    # based on the issues_list.json file which contains user requests to keep environments online after normal hours
    SKIP=$(should_skip_start_stop $managed_instance_env $managed_instance_business_area $MODE)

    log "====================================================="
    log "Processing SQL Managed Instance: $SERVER_NAME"
    log "====================================================="

    # If SKIP is false then we progress with the action (stop/start) for the particular Managed SQL Instance in this loop run, if not skip and print message to the logs
    if [[ $SKIP == "false" ]]; then
        if [[ $DEV_ENV != "true" ]]; then
            sqlmi_state_messages
            az sql mi $MODE --resource-group $RESOURCE_GROUP --mi $SERVER_NAME --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on sql server
        else
            ts_echo_color BLUE "Development Env: simulating state commands only."
            sqlmi_state_messages
        fi
    else
        ts_echo_color AMBER "SQL server $SERVER_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
    fi
done
