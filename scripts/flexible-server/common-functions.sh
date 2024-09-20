#!/bin/bash

# Function that accepts the PostgreSQL flexible server json as input and sets variables for later use to stop or start as required.
function get_flexible_sql_server_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $flexibleserver)
  log "$RESOURCE_GROUP"
  SERVER_ID=$(jq -r '.id' <<< $flexibleserver)
  log "$SERVER_ID"
  SERVER_NAME=$(jq -r '.name' <<< $flexibleserver)
  log "$SERVER_NAME"
  ENVIRONMENT=$(echo $SERVER_NAME | rev | cut -d'-' -f 1 | rev )
  log "$ENVIRONMENT"
  BUSINESS_AREA=$( jq -r 'if (.tags.businessArea | ascii_downcase) == "ss" then "cross-cutting" else .tags.businessArea | ascii_downcase end' <<< $flexibleserver)
  log "$BUSINESS_AREA"
  STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $flexibleserver)
  log "$STARTUP_MODE"
  SERVER_STATE=$(jq -r '.properties_state' <<< $flexibleserver)
  log "$SERVER_STATE"
  SUBSCRIPTION_ID=$(jq -r '.subscriptionId' <<< $flexibleserver)
  log "$SUBSCRIPTION_ID"
}

function flexible_server_state_messages() {
    ts_echo_color GREEN "About to run $MODE operation on flexible sql server $SERVER_NAME Resource Group: $RESOURCE_GROUP"
    ts_echo_color GREEN "Command to run: az postgres flexible sql server $MODE --resource-group $RESOURCE_GROUP --name $SERVER_NAME --no-wait || echo Ignoring any errors while $MODE operation on sql server"
}
