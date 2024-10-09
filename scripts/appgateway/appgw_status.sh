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

APPLICATION_GATEWAYS=$(get_application_gateways)

# For each App Gateway found in the function `get_application_gateways` start another loop
jq -c '.data[]' <<<$APPLICATION_GATEWAYS | while read application_gateway; do
    # Function that returns the Resource Group, Id and Name of the Application Gateway and its current state as variables
    get_application_gateways_details

    # Set variables based on inputs which are used to decide when to SKIP an environment
    if [[ $ENVIRONMENT == "stg" ]]; then
        application_gateway_env=${ENVIRONMENT/stg/Staging}
    elif [[ $ENVIRONMENT == "sbox" ]]; then
        application_gateway_env=${ENVIRONMENT/sbox/Sandbox}
    else
        application_gateway_env=$ENVIRONMENT
    fi

    application_gateway_business_area=$BUSINESS_AREA

    # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value
    # based on the issues_list.json file which contains user requests to keep environments online after normal hours
    SKIP=$(should_skip_start_stop $application_gateway_env $application_gateway_business_area $MODE)

    # Setup message output templates for later use
    logMessage="Application Gateway: $APPLICATION_GATEWAY_NAME in Subscription: $SUBSCRIPTION and ResourceGroup: $RESOURCE_GROUP is $APPLICATION_GATEWAY_STATE after $MODE action"
    slackMessage="Application Gateway: *$APPLICATION_GATEWAY_NAME* in Subscription: *$SUBSCRIPTION* is $APPLICATION_GATEWAY_STATE after *$MODE* action."

    # If SKIP is false then we progress with the status check for the particular App Gateway in this loop run, if SKIP is true then do nothing
    if [[ $SKIP == "false" ]]; then
        # Check state of the Application Gateway and print output as required
        # Depending on the value of MODE a notification will also be sent
        #    - If MODE = Start then a stopped App Gateway is incorrect and we should notify
        #    - If MODE = Stop then a running App Gateway is incorrect and we should notify
        #    - If neither Running or Stopped is found then something else is going on and we should notify
        case "$APPLICATION_GATEWAY_STATE" in
        *"Running"*)
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
        ts_echo_color AMBER "Application Gateway: $APPLICATION_GATEWAY_NAME in ResourceGroup: $RESOURCE_GROUP has been skipped from today's $MODE operation schedule"
    fi
done
