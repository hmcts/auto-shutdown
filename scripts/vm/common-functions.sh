#!/bin/bash

function get_subscription_vms() {
  SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
  SUBSCRIPTION_NAME=$(jq -r '.name' <<< $subscription)
  az account set -s $SUBSCRIPTION_ID
  VMS=$(az resource list --resource-type Microsoft.Compute/virtualMachines --query "[?tags.autoShutdown == 'true']" -o json)
}

function get_vm_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $vm)
  VM_ID=$(jq -r '.id' <<< $vm)
  VM_NAME=$(jq -r '.name' <<< $vm)
  VM_ENVIRONMENT=$(jq -r '.tags.environment' <<< $vm)
  VM_BUSINESS_AREA=$(jq -r '.tags.businessArea' <<< $vm)
  VM_STATE=$(az vm show -d --ids $VM_ID --query "powerState" | jq -r)
}