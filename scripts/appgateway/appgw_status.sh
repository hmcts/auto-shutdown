#!/usr/bin/env bash

shopt -s nocasematch

# Source shared function scripts
source scripts/appgateway/common-functions.sh
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

        # Set variables based on inputs which are used to decide when to SKIP an environment
        application_gateway_env=${ENVIRONMENT/stg/Staging}
        application_gateway_business_area=${BUSINESS_AREA/ss/cross-cutting}

        # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value
        # based on the issues_list.json file which contains user requests to keep environments online after normal hours
        SKIP=$(should_skip_start_stop $application_gateway_env $application_gateway_business_area $MODE)

        # Setup message output templates for later use
        logMessage="Application Gateway: $APPLICATION_GATEWAY_NAME in Subscription: $SUBSCRIPTION_NAME and ResourceGroup: $RESOURCE_GROUP is $APPLICATION_GATEWAY_STATE after $MODE action"
        slackMessage="Application Gateway: *$APPLICATION_GATEWAY_NAME* in Subscription: *$SUBSCRIPTION_NAME* is $APPLICATION_GATEWAY_STATE after *$MODE* action."

        # If SKIP is false then we progress with the status check for the particular App Gateway in this loop run, if SKIP is true then do nothing
        if [[ $SKIP == "false" ]]; then
        # Check state of the Application Gateway and print output as required
        # Depending on the value of MODE a notification will also be sent
        #    - If MODE = Start then a stopped App Gateway is incorrect and we should notify
        #    - If MODE = Stop then a running App Gateway is incorrect and we should notify
        #    - If neither Running or Stopped is found then something else is going on and we should notify
            case "$APPLICATION_GATEWAY_STATE" in
                *"Running"*)
                    ts_echo_color $( [[ $MODE == "start" ]] && echo GREEN || echo RED ) "$logMessage"
                    [[ $MODE == "stop" ]] && auto_shutdown_notification ":red_circle: $slackMessage"
                    ;;
                *"Stopped"*)
                    ts_echo_color $( [[ $MODE == "start" ]] && echo RED || echo GREEN ) "$logMessage"
                    [[ $MODE == "start" ]] && auto_shutdown_notification ":red_circle: $slackMessage"
                    ;;
                *)
                    ts_echo_color AMBER "$logMessage"
                    auto_shutdown_notification ":yellow_circle: $slackMessage"
                    ;;
            esac
        fi
    done
done
