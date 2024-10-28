#!/bin/bash

function get_vms() {
    #MS az graph query to find and return a list of all AKS tagged to be included in the auto-shutdown process.
    log "----------------------------------------------"
    log "Running az graph query..."

    if [ -z $1 ]; then
        env_selector=""
    elif [ $1 == "untagged" ]; then
        env_selector="| where isnull(tags.environment) and isnull(tags.Environment)"
    else
        env_selector="| where tags.environment contains '$1' or tags.Environment contains '$1'"
    fi

    if [ -z $2 ]; then
        area_selector=""
    else
        area_selector="| where tags.businessArea == '$2'"
    fi

    az graph query -q "
    resources
    | where type =~ 'Microsoft.Compute/virtualMachines'
    | where tags.autoShutdown == 'true'
    $env_selector
    $area_selector
    | project name, resourceGroup, subscriptionId, ['tags'], properties, ['id']
    " --first 1000 -o json

    log "az graph query complete"
}

# Function that accepts the VM json as input and sets variables for later use to stop or start VM
function get_vm_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup // "value_not_retrieved"' <<< $vm)
  VM_ID=$(jq -r '.properties.vmId' <<< $vm)
  VM_NAME=$(jq -r '.name' <<< $vm)
  ENVIRONMENT=$(jq -r '.tags.environment // .tags.Environment // "tag_not_set"' <<< "$vm")
  BUSINESS_AREA=$(jq -r 'if (.tags.businessArea // .tags.BusinessArea // "tag_not_set" | ascii_downcase) == "ss" then "cross-cutting" else (.tags.businessArea // .tags.BusinessArea // "tag_not_set" | ascii_downcase) end' <<< $vm)
  STARTUP_MODE=$(jq -r '.tags.startupMode // "false"' <<< $vm)
  VM_STATE=$(jq -r '.properties.extended.instanceView.powerState.code' <<< $vm)
  SUBSCRIPTION=$(jq -r '.subscriptionId' <<<$vm)
}

function vm_state_messages() {
    ts_echo_color GREEN "About to run $MODE operation on VM: $VM_NAME in Resource Group: $RESOURCE_GROUP"
    ts_echo_color GREEN  "Command to run: az vm $MODE --ids $VM_ID --no-wait || echo Ignoring any errors while $MODE operation on vm"
}
