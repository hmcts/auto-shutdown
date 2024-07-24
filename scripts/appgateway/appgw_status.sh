#!/usr/bin/env bash

shopt -s nocasematch

# Source shared function scripts
source scripts/appgateway/common-functions.sh
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
    # sets the subscription as the default then returns a json formatted variable of available App Gateways with an autoshutdown tag
    get_application_gateways
    echo "Scanning $SUBSCRIPTION_NAME..."

    # For each App Gateway found in the function `get_application_gateways` start another loop
    jq -c '.[]'<<< $APPLICATION_GATEWAYS | while read application_gateway
    do
        # Function that returns the Resource Group, Id and Name of the Application Gateway and its current state as variables
        get_application_gateways_details

        # Setup message output templates for later use
        logMessage="Application Gateway: $APPLICATION_GATEWAY_NAME in Subscription: $SUBSCRIPTION_NAME and ResourceGroup: $RESOURCE_GROUP is $APPLICATION_GATEWAY_STATE after $MODE action"
        slackMessage="SFTP Server on Storage Account: *$APPLICATION_GATEWAY_NAME* in Subscription: *$SUBSCRIPTION_NAME* is $APPLICATION_GATEWAY_STATE after *$MODE* action."

        # Check state of the Application Gateway and print output as required
        # Depending on the value of MODE a notification will also be sent
        #    - If MODE = Start then a stopped App Gateway is incorrect and we should notify
        #    - If MODE = Stop then a running App Gateway is incorrect and we should notify
        #    - If neither Running or Stopped is found then something else is going on and we should notify
        if [[ "$APPLICATION_GATEWAY_STATE" =~ "Running" ]]; then
            ts_echo_color $( [[ $MODE == "start" ]] && echo GREEN || echo RED ) "$logMessage"
            if [[ $MODE == "stop" ]]; then
                auto_shutdown_notification ":red_circle: $slackMessage"
            fi   
        elif [[  "$APPLICATION_GATEWAY_STATE" =~ "Stopped" ]]; then
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