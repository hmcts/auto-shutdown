#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/appgateway/common-functions.sh
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
    get_application_gateways
    echo "Scanning $SUBSCRIPTION_NAME..."

    # For each App Gateway found in the function `get_application_gateways` start another loop
    jq -c '.[]' <<< $APPLICATION_GATEWAYS | while read application_gateway; do

        # Function that returns the Resource Group, Id and Name of the Application Gateway and its current state as variables
        get_application_gateways_details

        # Set variables based on inputs which are used to decide when to SKIP an environment
        application_gateway_env=${ENVIRONMENT/stg/Staging}
        application_gateway_business_area=$BUSINESS_AREA

        # SKIP variable updated based on the output of the `should_skip_start_stop` function which calculates its value
        # based on the issues_list.json file which contains user requests to keep environments online after normal hours
        SKIP=$(should_skip_start_stop $application_gateway_env $application_gateway_business_area $MODE)

        # If SKIP is false then we progress with the action (stop/start) for the particular App Gateway in this loop run, if not skip and print message to the logs
        if [[ $SKIP == "false" ]]; then
            if [[ $DEV_ENV != "true" ]]; then
                appgateway_state_messages
                az network application-gateway $MODE --resource-group $RESOURCE_GROUP --name $APPLICATION_GATEWAY_NAME --no-wait || echo Ignoring any errors while $MODE operation on application_gateway
            else
                ts_echo_color BLUE "Development Env: simulating state commands only."
                appgateway_state_messages
            fi
        else
            ts_echo_color AMBER "Application_gateway $APPLICATION_GATEWAY_NAME (rg:$RESOURCE_GROUP) has been skipped from today's $MODE operation schedule"
        fi
    done
done
