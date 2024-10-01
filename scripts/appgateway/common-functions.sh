#!/bin/bash

function get_application_gateways() {
  #MS az graph query to find and return a list of all Application Gateways tagged to be included in the auto-shutdown process.
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
      | where type =~ 'microsoft.network/applicationgateways'
      | where tags.autoShutdown == 'true'
      $env_selector
      | project name, resourceGroup, subscriptionId, ['tags'], properties.operationalState, ['id']
    " --first 1000 -o json

  log "az graph query complete"
}

# Function that accepts the app gateway json as input and sets variables for later use to stop or start App Gateway
function get_application_gateways_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $application_gateway)
  APPLICATION_GATEWAY_NAME=$(jq -r '.name' <<< $application_gateway)
  ENVIRONMENT=$(echo $APPLICATION_GATEWAY_NAME | rev | cut -d'-' -f 2 | rev )
  SUBSCRIPTION=$(jq -r '.subscriptionId' <<< $application_gateway)
  BUSINESS_AREA=$( jq -r 'if (.tags.businessArea|ascii_downcase) == "ss" then "cross-cutting" else .tags.businessArea|ascii_downcase end' <<< $application_gateway)
  STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $application_gateway)
  APPLICATION_GATEWAY_STATE=$(jq -r '.properties_operationalState' <<< $application_gateway)
}

function appgateway_state_messages() {
  ts_echo_color GREEN "About to run $MODE operation on application gateway $APPLICATION_GATEWAY_NAME in Resource Group: $RESOURCE_GROUP"
  ts_echo_color GREEN "Command to run: az network application-gateway $MODE --resource-group $RESOURCE_GROUP --name $APPLICATION_GATEWAY_NAME --no-wait || echo Ignoring any errors while $MODE operation on application_gateway"
}