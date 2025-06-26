#!/bin/bash

# Function that uses the subscription input to get set variables for later use and gather all managed sql servers within the subscription for shutdown
function get_sql_mi_servers() {
  #MS az graph query to find and return a list of all SQL MI servers tagged to be included in the auto-shutdown process.
  log "----------------------------------------------"
  log "Running az graph query..."

  if [ -z $1 ]; then
    env_selector=""
  elif [ $1 == "untagged" ]; then
    env_selector="| where isnull(tags.environment)"
  else
    env_selector="| where tags.environment == '$1'"
  fi

  az graph query -q "
    resources
    | where type =~ 'microsoft.sql/managedinstances'
    | where tags.autoShutdown == 'true'
    | where tolower(tags.environment) in~ ('staging', 'development', 'demo', 'sandbox')
    $env_selector
    | project name, resourceGroup, subscriptionId, ['tags'], properties.state, ['id']
    " --first 1000 -o json

  log "az graph query complete"
}

# Function that accepts the managed sql server json as input and sets variables for later use to stop or start managed sql server
function get_sql_mi_server_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $server)
  SERVER_ID=$(jq -r '.id' <<< $server)
  SERVER_NAME=$(jq -r '.name' <<< $server)
  ENVIRONMENT=$(echo $SERVER_NAME | cut -d'-' -f 3)
  BUSINESS_AREA=$( jq -r 'if (.tags.businessArea|ascii_downcase) == "ss" then "cross-cutting" else .tags.businessArea|ascii_downcase end' <<< $server)
  SERVER_STATE=$(jq -r '.properties_state' <<< $server)
  STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $server)
  SUBSCRIPTION=$(jq -r '.subscriptionId' <<< $server)
}

function sqlmi_state_messages() {
    ts_echo_color GREEN "About to run $MODE operation on sql server $SERVER_NAME (rg:$RESOURCE_GROUP)"
    ts_echo_color GREEN "Command to run: az sql mi $MODE --resource-group $RESOURCE_GROUP --mi $SERVER_NAME --no-wait || echo Ignoring any errors while $MODE operation on sql server"
}