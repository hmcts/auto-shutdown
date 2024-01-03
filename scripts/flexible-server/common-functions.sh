#!/bin/bash

function get_subscription_flexible_sql_servers() {
  SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
  az account set -s $SUBSCRIPTION_ID
  FLEXIBLE_SERVERS=$(az resource list --resource-type Microsoft.DBforPostgreSQL/flexibleServers  --query "[?tags.autoShutdown == 'true']" -o json)
}

function get_flexible_sql_server_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $server)
  SERVER_NAME=$(jq -r '.name' <<< $server)
  STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $server)
}