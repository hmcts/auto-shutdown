#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/mysql-flexible/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
MODE=${1:-start}
SKIP="false"

# Catch problems with MODE input, must be one of Start/Stop
if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

MYSQL_SERVERS=$(get_mysql_servers "$2" "$3" "$4")
mysql_server_count=$(jq -c -r '.count' <<< $MYSQL_SERVERS)
log "$mysql_server_count MySQL Flexible Servers found"
log "----------------------------------------------"


# For each MySQL Flexible Server returned from the az graph query start another loop
jq -c '.data[]' <<<$MYSQL_SERVERS | while read mysqlserver; do

    # Function that returns details of the MySQL Flexible Server json output.
    get_mysql_server_details

    # Set variables based on inputs which are used to decide when to SKIP an environment
    if [[ $ENVIRONMENT == "stg" ]]; then
        mysql_server_env=${ENVIRONMENT/stg/Staging}
    elif [[ $ENVIRONMENT == "sbox" ]]; then
        mysql_server_env=${ENVIRONMENT/sbox/Sandbox}
    elif [[ $ENVIRONMENT == "prod" ]]; then
        mysql_server_env=${ENVIRONMENT/prod/Production}
    else
        mysql_server_env=$ENVIRONMENT
    fi

    mysql_server_business_area=$BUSINESS_AREA

    log "====================================================="
    log "Processing MySQL Flexible Server: $SERVER_NAME"
    log "====================================================="

    # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value
    # based on the issues_list.json file which contains user requests to keep environments online after normal hours
    SKIP=$(should_skip_start_stop $mysql_server_env $mysql_server_business_area $MODE "mysql-flexible")

    # If SKIP is false then we progress with the action (stop/start) for the particular MySQL Flexible Server in this loop run, if not skip and print message to the logs
    if [[ $SKIP == "false" ]]; then
        if [[ $DEV_ENV != "true" ]]; then
            mysql_server_state_messages
            az mysql flexible-server $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on mysql flexible server
        else
            ts_echo_color BLUE "Development Env: simulating state commands only."
            mysql_server_state_messages
        fi
    else
        ts_echo_color AMBER "MySQL flexible server $SERVER_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
    fi
done
