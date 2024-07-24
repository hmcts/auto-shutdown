#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/sqlmi/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
# notificationSlackWebhook is used during the function call `auto_shutdown_notification`
MODE=${1:-start}
notificationSlackWebhook=$2

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

    # For each App Gateway found in the function `get_application_gateways` start another loop
    jq -c '.[]'<<< $MI_SQL_SERVERS | while read server; do

        # Function that returns the Resource Group, Id and Name of the Application Gateway and its current state as variables
        get_sql_mi_server_details

        # Setup message output templates for later use
        logMessage="SQL managed-instance: $SERVER_NAME in Subscription: $SUBSCRIPTION_NAME and ResourceGroup: $RESOURCE_GROUP is $SERVER_STATE after $MODE action"
        slackMessage="SQL managed-instance: *$SERVER_NAME* in Subscription: *$SUBSCRIPTION_NAME* and ResourceGroup: *$RESOURCE_GROUP* is *$SERVER_STATE* after *$MODE* action"

        # Check state of the Managed SQL Instance and print output as required
        # Depending on the value of MODE a notification will also be sent
        #    - If MODE = Start then a stopped App Gateway is incorrect and we should notify
        #    - If MODE = Stop then a running App Gateway is incorrect and we should notify
        #    - If neither Running or Stopped is found then something else is going on and we should notify
        if [[ "$SERVER_STATE" =~ "Ready" ]]; then
            ts_echo_color $( [[ $MODE == "start" ]] && echo GREEN || echo RED ) "$logMessage"
            if [[ $MODE == "stop" ]]; then
                auto_shutdown_notification ":red_circle: $slackMessage"
            fi
        elif [[  "$SERVER_STATE" =~ "Stopped" ]]; then
            ts_echo_color $( [[ $MODE == "start" ]] && echo RED || echo GREEN ) "$logMessage"
            if [[ $MODE == "start" ]]; then
                auto_shutdown_notification ":red_circle: $slackMessage"
            fi
        else
            ts_echo_color ${AMBER} "$logMessage"
            auto_shutdown_notification ":yellow_circle: $slackMessage"
        fi

    done
done
