#!/bin/bash

function _vmss_query_where() {
    local env_selector=$(env_selector "$1")
    local area_selector=$(area_selector "$2")

    echo "| where type =~ 'Microsoft.Compute/virtualMachineScaleSets/VirtualMachines'
          | where tags.autoShutdown == 'true'
          | where not (name matches regex '(^aks-|-aks-|-aks$)')
          $env_selector
          $area_selector"
}

function _vmss_query_extend() {
    echo "| extend vmssId = replace(@'\/virtualMachines\/[^\/]+$', '', id)
          | extend vmssName = extract(@'/([^\/]+)/virtualMachines/[^\/]+$', 1, id)"
}

function _vmss_query_project() {
    echo "| project vmssId, vmssName, resourceGroup, subscriptionId, ['tags'], powerState = properties.extended.instanceView.powerState.code"
}

function _vmss_query_summarise() {
    echo "| summarize count() by tostring(powerState), vmssId, vmssName, resourceGroup, subscriptionId, tostring(['tags'])"
}

function get_vmss() {
    # Azure graph query to find and return a list of all VMSS tagged to be included in the auto-shutdown process.
    log "----------------------------------------------"
    log "Running az graph query..."
    
    local query_where=$(_vmss_query_where "$1" "$2")
    
    az graph query -q "
    computeresources
    | where subscriptionId in ('bf308a5c-0624-4334-8ff8-8dca9fd43783')
    $query_where
    $(_vmss_query_extend) $(_vmss_query_project) $(_vmss_query_summarise)
    " --first 1000 -o json | jq -c -r '.data |= map(.tags |= fromjson)'

    log "az graph query complete" 
}

# Get all VM Scale Sets uniform instances. Does not include flexible instances which we do not use.
#
# Environment and business area matching is case-insensitive.
#
# Usage: get_vmss_instances [environment] [business_area]
# Example: get_vmss_instances "development" "cross-cutting"
#
function get_vmss_instances() {
    log "----------------------------------------------"
    log "Running az graph query..."
    
    local query_where=$(_vmss_query_where "$1" "$2")

    az graph query -q "
    computeresources
    $query_where
    $(_vmss_query_extend)
    | extend instanceIdx = extract(@'/virtualMachines/([^\/]+)$', 1, id)
    $(_vmss_query_project),
        osType = properties.storageProfile.osDisk.osType,
        vmSize=properties.hardwareProfile.vmSize,
        instanceIdx
    "  --first 1000 -o json

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
    $(_vmss_query_extend)
    | where vmssId == '$vmss_id'
    $(_vmss_query_project) $(_vmss_query_summarise)
    " --first 1 -o json | jq -c -r '.data |= map(.tags |= fromjson) | .data[0]'

    log "az graph query complete"
}

# Retrieve details of a single VM Scale Set from a JSON object as returned by get_vmss.
#
# Usage: get_vmss_details [vmss_json]
#
function get_vmss_details() {
    local vmss="$1"
    local tags=$(jq -r '.tags' <<< $vmss)

    RESOURCE_GROUP=$(jq -r '.resourceGroup // "value_not_retrieved"' <<< $vmss)
    SUBSCRIPTION=$(jq -r '.subscriptionId' <<< $vmss)
    ENVIRONMENT=$(jq -r '.environment // .Environment // "tag_not_set"' <<< $tags)
    BUSINESS_AREA=$(jq -r 'if (.businessArea // .BusinessArea // "tag_not_set" | ascii_downcase) == "ss" then "cross-cutting" else (.businessArea // .BusinessArea // "tag_not_set" | ascii_downcase) end' <<< $tags)

    VMSS_NAME=$(jq -r '.vmssName' <<< $vmss)
    VMSS_ID=$(jq -r '.vmssId' <<< $vmss)
    VMSS_STARTUP_MODE=$(jq -r '.startupMode // "false"' <<< $tags)
    VMSS_STATE=$(jq -r '.powerState | split("/")[1]' <<< $vmss)
}

# Retrieve details of a single VM Scale Set instance from a JSON object as returned by get_vmss_instances.
#
# Usage: get_vmss_instance_details [vmss_instance_json]
#
get_vmss_instance_details() {
    local vmss_ins="$1"
    get_vmss_details "$vmss_ins"

    VMSS_INSTANCE_IDX=$(jq -r '.instanceIdx // null' <<<$vmss_ins)
    VMSS_OS=$(jq -r '.osType // null' <<<$vmss_ins)
    VMSS_SKU=$(jq -r '.vmSize // null' <<<$vmss_ins)
}

function vmss_state_messages() {
    ts_echo_color GREEN "About to run $MODE operation on VMSS: $VMSS_NAME in Resource Group: $RESOURCE_GROUP"
    ts_echo_color GREEN  "Command to run: az vmss $MODE --name $VMSS_NAME --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION --no-wait || echo Ignoring any errors while $MODE operation on vmss"
}
