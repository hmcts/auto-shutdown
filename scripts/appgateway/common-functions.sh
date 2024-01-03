#!/bin/bash

function get_application_gateways() {
  SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
  az account set -s $SUBSCRIPTION_ID
  APPLICATION_GATEWAYS=$(az resource list --resource-type Microsoft.Network/applicationGateways  --query "[?tags.autoShutdown == 'true']" -o json)
}

function get_application_gateways_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $application_gateway)
  APPLICATION_GATEWAY_NAME=$(jq -r '.name' <<< $application_gateway)
  STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $application_gateway)
}