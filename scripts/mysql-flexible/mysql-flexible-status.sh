#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/mysql-flexible/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
# slack token for the shutdown status app is passed as env var and used to post a thread with all the individual resource statuses
MODE=${1:-start}
SKIP="false"

# Catch problems with MODE input, must be one of Start/Stop
if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

MYSQL_SERVERS=$(get_mysql_servers)
mysql_server_count=$(jq -c -r '.count' <<< $MYSQL_SERVERS)
log "$mysql_server_count MySQL Flexible Servers found"
log "----------------------------------------------"

auto_shutdown_notifications=""
# For each MySQL Flexible Server found in the function `get_mysql_servers` start another loop
while read mysqlserver; do
    # Function that returns the Resource Group, Id and Name of the MySQL Flexible Server and its current state as variables
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

    # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value
    # based on the issues_list.json file which contains user requests to keep environments online after normal hours
    SKIP=$(should_skip_start_stop $mysql_server_env $mysql_server_business_area $MODE "mysql-flexible")

    # Setup message output templates for later use
    logMessage="MySQL Flexible Server: $SERVER_NAME in Subscription: $SUBSCRIPTION  ResourceGroup: $RESOURCE_GROUP is in $SERVER_STATE state after $MODE action"
    slackMessage="MySQL Flexible Server: *$SERVER_NAME* in Subscription: *$SUBSCRIPTION* is in *$SERVER_STATE* state after *$MODE* action"

    # If SKIP is false then we progress with the status check for the particular MySQL flexible server in this loop run, if SKIP is true then do nothing
    if [[ $SKIP == "false" ]]; then
        log "$logMessage"
        auto_shutdown_notifications+=":red_circle: $slackMessage|"
    else
        ts_echo_color AMBER "MySQL flexible server $SERVER_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE status notification"
    fi
done < <(jq -c '.data[]' <<<$MYSQL_SERVERS)

post_entire_autoshutdown_thread ":red_circle: :sql: MySQL Flexible START status check" "$auto_shutdown_notifications"
