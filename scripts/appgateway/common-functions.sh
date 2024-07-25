#!/bin/bash

# Function that uses the subscription input to get set variables for later use and gather all app gateways within the subscription for shutdown
function get_application_gateways() {
  SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
  SUBSCRIPTION_NAME=$(jq -r '.name' <<< $subscription)
  az account set -s $SUBSCRIPTION_ID
  APPLICATION_GATEWAYS=$(az resource list --resource-type Microsoft.Network/applicationGateways  --query "[?tags.autoShutdown == 'true']" -o json)
}

# Function that accepts the app gateway json as input and sets variables for later use to stop or start App Gateway
function get_application_gateways_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $application_gateway)
  APPLICATION_GATEWAY_ID=$(jq -r '.id' <<< $application_gateway)
  APPLICATION_GATEWAY_NAME=$(jq -r '.name' <<< $application_gateway)
  ENVIRONMENT=$(echo $APPLICATION_GATEWAY_NAME | rev | cut -d'-' -f 2 | rev )
  BUSINESS_AREA=$( jq -r '.tags.businessArea' <<< $application_gateway)
  STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $application_gateway)
  APPLICATION_GATEWAY_STATE=$(az network application-gateway show --ids $APPLICATION_GATEWAY_ID | jq -r .operationalState)
}
