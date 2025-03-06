#!/bin/bash

function get_vmss() {
    #MS az graph query to find and return a list of all VMSS tagged to be included in the auto-shutdown process.
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
        area_selector="| where tolower(tags.businessArea) == tolower('$2')"
    fi

   az graph query -q "
    resources
    | where type =~ 'Microsoft.Compute/virtualMachineScaleSets'
    | where subscriptionId in ('7a4e3bd5-ae3a-4d0c-b441-2188fee3ff1c', '1c4f0704-a29e-403d-b719-b90c34ef14c9', 'bf308a5c-0624-4334-8ff8-8dca9fd43783')
    | where tags.autoShutdown == 'test'
    | where not (name matches regex '(^aks-|-aks-|-aks$)')
    | where not (resourceGroup matches regex '(^aks-|-aks-|-aks$)')
    $env_selector
    $area_selector
    | project *
    " --first 1000 -o json

    log "az graph query complete" 
}

# Function that accepts the VMSS json as input and sets variables for later use to stop or start VMSS
function get_vmss_details() {
  echo $vmss
  RESOURCE_GROUP=$(jq -r '.resourceGroup // "value_not_retrieved"' <<< $vmss)
  VMSS_NAME=$(jq -r '.name' <<< $vmss)
  ENVIRONMENT=$(jq -r '.tags.environment // .tags.Environment // "tag_not_set"' <<< "$vmss")
  BUSINESS_AREA=$(jq -r 'if (.tags.businessArea // .tags.BusinessArea // "tag_not_set" | ascii_downcase) == "ss" then "cross-cutting" else (.tags.businessArea // .tags.BusinessArea // "tag_not_set" | ascii_downcase) end' <<< $vmss)
  STARTUP_MODE=$(jq -r '.tags.startupMode // "false"' <<< $vmss)
  VMSS_STATE=$(jq -r '.properties_extended_instanceView_powerState_displayStatus' <<< $vmss)
  SUBSCRIPTION=$(jq -r '.subscriptionId' <<<$vmss)
  VMSS_ID="/subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachineScaleSets/$VMSS_NAME"
}

function vmss_state_messages() {
    ts_echo_color GREEN "About to run $MODE operation on VMSS: $VMSS_NAME in Resource Group: $RESOURCE_GROUP"
    ts_echo_color GREEN  "Command to run: az vmss $MODE --name $VMSS_NAME --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on vmss"
}

