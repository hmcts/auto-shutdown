#!/bin/bash

function get_subscription_vms() {
  SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
  SUBSCRIPTION_NAME=$(jq -r '.name' <<<$subscription)
  az account set -s $SUBSCRIPTION_ID
  VMS=$(az resource list --resource-type Microsoft.Compute/virtualMachines --query "[?tags.autoShutdown == 'true']" -o json)
}

function get_vm_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $vm)
  VM_NAME=$(jq -r '.name' <<< $vm)
  STARTUP_MODE=$(jq -r '.tags.startupMode' <<< $vm)
}