#!/bin/bash
function get_flexible_sql_servers() {
  #MS az graph query to find and return a list of all PostgreSQL Flexible Servers tagged to be included in the auto-shutdown process.
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
    | where type =~ 'microsoft.dbforpostgresql/flexibleservers'
    | where tags.autoShutdown == 'true'
    $env_selector
    | project name, resourceGroup, subscriptionId, ['tags'], properties.state, ['id']
    " --first 1000 -o json

  log "az graph query complete"
}


# Function that accepts the PostgreSQL flexible server json as input and sets variables for later use to stop or start as required.
function get_flexible_sql_server_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $flexibleserver)
  SERVER_ID=$(jq -r '.id' <<< $flexibleserver)
  SERVER_NAME=$(jq -r '.name' <<< $flexibleserver)
  ENVIRONMENT=$(echo $SERVER_NAME | rev | cut -d'-' -f 1 | rev )
  BUSINESS_AREA=$( jq -r 'if (.tags.businessArea | ascii_downcase) == "ss" then "cross-cutting" else .tags.businessArea | ascii_downcase end' <<< $flexibleserver)
  STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $flexibleserver)
  SERVER_STATE=$(jq -r '.properties_state' <<< $flexibleserver)
  SUBSCRIPTION_ID=$(jq -r '.subscriptionId' <<< $flexibleserver)
}

function flexible_server_state_messages() {
    ts_echo_color GREEN "About to run $MODE operation on flexible sql server $SERVER_NAME Resource Group: $RESOURCE_GROUP"
    ts_echo_color GREEN "Command to run: az postgres flexible sql server $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --no-wait || echo Ignoring any errors while $MODE operation on sql server"
}
