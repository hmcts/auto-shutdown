#!/bin/bash

# Function that uses the subscription input to get set variables for later use and gather all VMs within the subscription for shutdown
function get_subscription_vms() {
  SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
  SUBSCRIPTION_NAME=$(jq -r '.name' <<< $subscription)
  az account set -s $SUBSCRIPTION_ID
  VMS=$(az resource list --resource-type Microsoft.Compute/virtualMachines --query "[?tags.autoShutdown == 'true']" -o json)
}

# Function that accepts the VM json as input and sets variables for later use to stop or start VM
function get_vm_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $vm)
  VM_ID=$(jq -r '.id' <<< $vm)
  VM_NAME=$(jq -r '.name' <<< $vm)
  ENVIRONMENT=$(jq -r '.tags.environment' <<< $vm)
  BUSINESS_AREA=$(jq -r '.tags.businessArea' <<< $vm)
  STARTUP_MODE=$(jq -r '.tags.startupMode // "false"' <<< $vm)
  VM_STATE=$(az vm show -d --ids $VM_ID --query "powerState" | jq -r)

}
