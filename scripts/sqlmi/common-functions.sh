#!/bin/bash

# Function that uses the subscription input to get set variables for later use and gather all managed sql servers within the subscription for shutdown
function get_sql_mi_servers() {
  SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
  SUBSCRIPTION_NAME=$(jq -r '.name' <<< $subscription)
  az account set -s $SUBSCRIPTION_ID
  MI_SQL_SERVERS=$(az resource list --resource-type Microsoft.Sql/managedInstances --query "[?tags.autoShutdown == 'true']" -o json)
}

# Function that accepts the managed sql server json as input and sets variables for later use to stop or start managed sql server
function get_sql_mi_server_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $server)
  SERVER_ID=$(jq -r '.id' <<< $server)
  SERVER_NAME=$(jq -r '.name' <<< $server)
  ENVIRONMENT=$(echo $SERVER_NAME | cut -d'-' -f 3)
  BUSINESS_AREA=$( jq -r '.tags.businessArea' <<< $server)
  SERVER_STATE=$(az sql mi show --ids $SERVER_ID --query "state")
  STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $server)
}
