#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/flexible-server/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
notificationSlackWebhook=$2

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
     echo "Invalid MODE. Please use 'start' or 'stop'."
     exit 1
fi

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription 
do

     get_subscription_flexible_sql_servers
     
     jq -c '.[]'<<< $FLEXIBLE_SERVERS | while read flexibleserver
     do
          get_flexible_sql_server_details

          logMessage="Flexible SQL Server:: $SERVER_NAME in Subscription: $SUBSCRIPTION_NAME  ResourceGroup: $RESOURCE_GROUP is in $SERVER_STATE state after $MODE action"
          slackMessage="Flexible SQL Server: *$SERVER_NAME* in Subscription: *$SUBSCRIPTION_NAME* is in *$SERVER_STATE* state after *$MODE* action"

          if [[ "$SERVER_STATE" =~ .*"Ready".* ]]; then
               ts_echo_color $( [[ $MODE == "start" ]] && echo GREEN || echo RED ) "$logMessage"
               if [[ $MODE == "stop" ]]; then
                    auto_shutdown_notification ":red_circle: $slackMessage"
               fi
          elif [[ "$SERVER_STATE" =~ .*"Stopped".* ]]; then
               ts_echo_color $( [[ $MODE == "start" ]] && echo RED || echo GREEN ) "$logMessage"
               if [[ $MODE == "start" ]]; then
                    auto_shutdown_notification ":red_circle: $slackMessage"
               fi  
          else
               ts_echo_color AMBER "$logMessage"
               auto_shutdown_notification ":yellow_circle: $slackMessage"
          fi

     done
done   
