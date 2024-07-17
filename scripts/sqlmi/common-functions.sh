#!/bin/bash

function get_sql_mi_servers() {
  SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
  SUBSCRIPTION_NAME=$(jq -r '.name' <<< $subscription)
  az account set -s $SUBSCRIPTION_ID
  MI_SQL_SERVERS=$(az resource list --resource-type Microsoft.Sql/managedInstances --query "[?tags.autoShutdown == 'true']" -o json)
}

function get_sql_mi_server_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $server)
  SERVER_ID=$(jq -r '.id' <<< $server)
  SERVER_NAME=$(jq -r '.name' <<< $server)
  SERVER_STATE=$(az sql mi show --ids $SERVER_ID --query "state")
  STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $server)
}