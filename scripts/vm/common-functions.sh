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
  BUSINESS_AREA=$( jq -r 'if (.tags.businessArea | ascii_downcase?) == "ss" then "cross-cutting" else .tags.businessArea | ascii_downcase? end' <<< $vm)
  STARTUP_MODE=$(jq -r '.tags.startupMode // "false"' <<< $vm)
  VM_STATE=$(az vm show -d --ids $VM_ID --query "powerState" | jq -r)

}

function vm_state_messages() {
    ts_echo_color GREEN "About to run $MODE operation on VM: $VM_NAME in Resource Group: $RESOURCE_GROUP"
    ts_echo_color GREEN  "Command to run: az vm $MODE --ids $VM_ID --no-wait || echo Ignoring any errors while $MODE operation on vm"
}
