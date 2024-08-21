#!/bin/bash

# Function that uses the subscription input to get set variables for later use and gather all flexible sql servers within the subscription for shutdown
function get_subscription_flexible_sql_servers() {
  SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
  SUBSCRIPTION_NAME=$(jq -r '.name' <<< $subscription)
  az account set -s $SUBSCRIPTION_ID
  FLEXIBLE_SERVERS=$(az resource list --resource-type Microsoft.DBforPostgreSQL/flexibleServers --query "[?tags.autoShutdown == 'true']" -o json)
}

# Function that accepts the flexible sql server json as input and sets variables for later use to stop or start the flexible sql server
function get_flexible_sql_server_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $flexibleserver)
  SERVER_ID=$(jq -r '.id' <<< $flexibleserver)
  SERVER_NAME=$(jq -r '.name' <<< $flexibleserver)
  ENVIRONMENT=$(echo $SERVER_NAME | rev | cut -d'-' -f 1 | rev )
  BUSINESS_AREA=$( jq -r 'if (.tags.businessArea | ascii_downcase) == "ss" then "cross-cutting" else .tags.businessArea | ascii_downcase end' <<< $flexibleserver)
  STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $flexibleserver)
  SERVER_STATE=$(az postgres flexible-server show --ids $SERVER_ID --query "state" | jq -r)

}

function flexible_server_state_messages() {
    ts_echo_color GREEN "About to run $MODE operation on flexible sql server $SERVER_NAME Resource Group: $RESOURCE_GROUP"
    ts_echo_color GREEN "Command to run: az postgres flexible sql server $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --no-wait || echo Ignoring any errors while $MODE operation on sql server"
}
