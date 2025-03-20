#!/bin/bash

function vmss_query_extend() {
    echo "| extend vmssId = replace(@'\/virtualMachines\/[^\/]+$', '', id)
          | extend name = extract(@'/([^\/]+)/virtualMachines/[^\/]+$', 1, id)"
}

function vmss_query_columns() {
    echo "| project vmssId, name, resourceGroup, subscriptionId, ['tags'], powerState = properties.extended.instanceView.powerState.code
          | summarize count() by tostring(powerState), vmssId, name, resourceGroup, subscriptionId, tostring(['tags'])"
}

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
    computeresources
    | where type =~ 'Microsoft.Compute/virtualMachineScaleSets/VirtualMachines'
    | where subscriptionId in ('bf308a5c-0624-4334-8ff8-8dca9fd43783','7a4e3bd5-ae3a-4d0c-b441-2188fee3ff1c', '1c4f0704-a29e-403d-b719-b90c34ef14c9')
    | where tags.autoShutdown == 'true'
    | where not (name matches regex '(^aks-|-aks-|-aks$)')
    $env_selector
    $area_selector
    $(vmss_query_extend)
    $(vmss_query_columns)
    " --first 1000 -o json | jq -c -r '.data |= map(.tags |= fromjson)'

    log "az graph query complete" 
}

# get VMSS with aggregated power status by id
#
# Usage: get_vmss_by_id <vmss_id>
#
function get_vmss_by_id() {
    local vmss_id=$1
    
    if [ -z $vmss_id ]; then
        log "No VMSS ID provided"
        exit 1
    fi

    az graph query -q "
    computeresources
    | where type =~ 'Microsoft.Compute/virtualMachineScaleSets/VirtualMachines'
    $(vmss_query_extend)
    $(vmss_query_columns)
    " --first 1 -o json | jq -c -r '.data |= map(.tags |= fromjson) | .data[0]'

    log "az graph query complete" 
}

# Function that accepts the VMSS json as input and sets variables for later use to stop or start VMSS
function get_vmss_details() {
  local tags=$(jq -r '.tags' <<< $vmss)

  RESOURCE_GROUP=$(jq -r '.resourceGroup // "value_not_retrieved"' <<< $vmss)
  VMSS_NAME=$(jq -r '.name' <<< $vmss)
  ENVIRONMENT=$(jq -r '.environment // .Environment // "tag_not_set"' <<< $tags)
  BUSINESS_AREA=$(jq -r 'if (.businessArea // .BusinessArea // "tag_not_set" | ascii_downcase) == "ss" then "cross-cutting" else (.businessArea // .BusinessArea // "tag_not_set" | ascii_downcase) end' <<< $tags)
  STARTUP_MODE=$(jq -r '.startupMode // "false"' <<< $tags)
  VMSS_STATE=$(jq -r '.powerState | split("/")[1]' <<< $vmss)
  SUBSCRIPTION=$(jq -r '.subscriptionId' <<< $vmss)
  VMSS_ID=$(jq -r '.vmssId' <<< $vmss)
}

function vmss_state_messages() {
    ts_echo_color GREEN "About to run $MODE operation on VMSS: $VMSS_NAME in Resource Group: $RESOURCE_GROUP"
    ts_echo_color GREEN  "Command to run: az vmss $MODE --name $VMSS_NAME --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on vmss"
}
