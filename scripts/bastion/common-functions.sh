#!/bin/bash

function get_bastions() {
    #MS az graph query to find and return bastion hosts based on environment and tags
    log "----------------------------------------------"
    log "Running az graph query..."

    az graph query -q "
    resources
    | where type =~ 'Microsoft.Compute/virtualMachines'
    | where tags.builtFrom == 'https://github.com/hmcts/bastion'
    | where tags.autoShutdown == 'true'
    | where tolower(tags.environment) in~ ('staging', 'development', 'demo', 'ithc', 'production', 'sandbox', 'testing')
    | where tags.environment contains '$1' or tags.Environment contains '$1'
    | extend powerState = properties.extended.instanceView.powerState.displayStatus
    | project name, resourceGroup, subscriptionId, tags, powerState, id
    " --first 10 -o json

    log "az graph query complete"
}

# Function that accepts the VM json as input and sets variables for later use to stop or start VM
function get_bastion_details() {
    RESOURCE_GROUP=$(jq -r '.resourceGroup // "value_not_retrieved"' <<< $bastion)
    VM_NAME=$(jq -r '.name' <<< $bastion)
    ENVIRONMENT=$(jq -r '.tags.environment // .tags.Environment // "tag_not_set"' <<< "$bastion")
    BUSINESS_AREA=$(jq -r 'if (.tags.businessArea // .tags.BusinessArea // "tag_not_set" | ascii_downcase) == "ss" then "cross-cutting" else (.tags.businessArea // .tags.BusinessArea // "tag_not_set" | ascii_downcase) end' <<< $bastion)
    STARTUP_MODE=$(jq -r '.tags.startupMode // "false"' <<< $bastion)
    VM_STATE=$(jq -r '.powerState' <<< $bastion)
    SUBSCRIPTION=$(jq -r '.subscriptionId' <<<$bastion)
    VM_ID=$(jq -r '.id' <<<$bastion)
}

function vm_state_messages() {
    ts_echo_color GREEN "About to run $MODE operation on VM: $VM_NAME in Resource Group: $RESOURCE_GROUP"
    ts_echo_color GREEN  "Command to run: az vm $MODE --ids $VM_ID --no-wait || echo Ignoring any errors while $MODE operation on vm"
}
