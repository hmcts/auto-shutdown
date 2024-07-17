#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/appgateway/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
notificationSlackWebhook=$2

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
     # Function that returns the Subscription Id and Name as variables, sets the subscription as the default then returns a json formatted variable of available App Gateways with an autoshutdown tag
     get_application_gateways

     jq -c '.[]'<<< $APPLICATION_GATEWAYS | while read application_gateway
     do
          # Function that returns the Resource Group, Id and Name of the Application Gateway and its current state as variables
          get_application_gateways_details

          logMessage="Application Gateway: $APPLICATION_GATEWAY_NAME in Subscription: $SUBSCRIPTION_NAME and ResourceGroup: $RESOURCE_GROUP is $APPLICATION_GATEWAY_STATE after $MODE action"
          slackMessage="SFTP Server on Storage Account: *$APPLICATION_GATEWAY_NAME* in Subscription: *$SUBSCRIPTION_NAME* is $APPLICATION_GATEWAY_STATE after *$MODE* action."

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
