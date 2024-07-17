#!/bin/bash

function get_subscription_flexible_sql_servers() {
  SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
  SUBSCRIPTION_NAME=$(jq -r '.name' <<< $subscription)
  az account set -s $SUBSCRIPTION_ID
  FLEXIBLE_SERVERS=$(az resource list --resource-type Microsoft.DBforPostgreSQL/flexibleServers --query "[?tags.autoShutdown == 'true']" -o json)
}

function get_flexible_sql_server_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $flexibleserver)
  SERVER_ID=$(jq -r '.id' <<< $flexibleserver)
  SERVER_NAME=$(jq -r '.name' <<< $flexibleserver)
  STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $flexibleserver)
  SERVER_STATE=$(az postgres flexible-server show --ids $SERVER_ID --query "state" | jq -r)
}