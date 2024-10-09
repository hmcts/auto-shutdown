#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/flexible-server/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
# notificationSlackWebhook is used during the function call `auto_shutdown_notification`
MODE=${1:-start}
notificationSlackWebhook=$2
SKIP="false"

# Catch problems with MODE input, must be one of Start/Stop
if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

FLEXIBLE_SERVERS=$(get_flexible_sql_servers)

# For each Flexible SQL Server found in the function `get_subscription_flexible_sql_servers` start another loop
jq -c '.data[]' <<<$FLEXIBLE_SERVERS | while read flexibleserver; do
    # Function that returns the Resource Group, Id and Name of the Flexible SQL Server and its current state as variables
    get_flexible_sql_server_details

    # Set variables based on inputs which are used to decide when to SKIP an environment
    if [[ $ENVIRONMENT == "stg" ]]; then
        flexible_server_env=${ENVIRONMENT/stg/Staging}
    elif [[ $ENVIRONMENT == "sbox" ]]; then
        flexible_server_env=${ENVIRONMENT/sbox/Sandbox}
    else
        flexible_server_env=$ENVIRONMENT
    fi

    flexible_server_business_area=$BUSINESS_AREA

    # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value
    # based on the issues_list.json file which contains user requests to keep environments online after normal hours
    SKIP=$(should_skip_start_stop $flexible_server_env $flexible_server_business_area $MODE)

    # Setup message output templates for later use
    logMessage="Flexible SQL Server: $SERVER_NAME in Subscription: $SUBSCRIPTION  ResourceGroup: $RESOURCE_GROUP is in $SERVER_STATE state after $MODE action"
    slackMessage="Flexible SQL Server: *$SERVER_NAME* in Subscription: *$SUBSCRIPTION* is in *$SERVER_STATE* state after *$MODE* action"

    # If SKIP is false then we progress with the status check for the particular Flexible server in this loop run, if SKIP is true then do nothing
    if [[ $SKIP == "false" ]]; then
        # Check state of the Flexible SQL Server and print output as required
        # Depending on the value of MODE a notification will also be sent
        #    - If MODE = Start then a stopped Flexible SQL Server is incorrect and we should notify
        #    - If MODE = Stop then a running Flexible SQL Server is incorrect and we should notify
        #    - If neither Running or Stopped is found then something else is going on and we should notify
        case "$SERVER_STATE" in
        *"Ready"*)
            ts_echo_color $([[ $MODE == "start" ]] && echo GREEN || echo RED) "$logMessage"
            if [[ $MODE == "stop" ]]; then
                auto_shutdown_notification ":red_circle: $slackMessage"
            fi
            ;;
        *"Stopped"*)
            ts_echo_color $([[ $MODE == "start" ]] && echo RED || echo GREEN) "$logMessage"
            if [[ $MODE == "start" ]]; then
                auto_shutdown_notification ":red_circle: $slackMessage"
            fi
            ;;
        *)
            ts_echo_color AMBER "$logMessage"
            auto_shutdown_notification ":yellow_circle: $slackMessage"
            ;;
        esac
    else
        ts_echo_color AMBER "Flexible SQL Server: $SERVER_NAME in ResourceGroup: $RESOURCE_GROUP has been skipped from today's $MODE operation schedule"
    fi
done
