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
    | project name, resourceGroup, subscriptionId, ['tags'], properties.extended.instanceView.powerState.displayStatus, ['id']
    " --first 1000 -o json

    log "az graph query complete" 
}

# Function that accepts the VMSS json as input and sets variables for later use to stop or start VMSS
function get_vmss_details() {
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

# Gets the power state of a specific Virtual Machine Scale Set (VMSS) instance
#
# param:
#   $1 - vmss_name: Name of the Virtual Machine Scale Set
#   $2 - resource_group: Name of the resource group containing the VMSS
#   $3 - subscription: Azure subscription ID
#   $4 - instance_id: ID of the specific VMSS instance
#
# return:
#   The power state of the VMSS instance (e.g., "PowerState/running", "PowerState/deallocated")
#
function get_vmss_instance_power_state() {
    local vmss_name="$1"
    local resource_group="$2"
    local subscription="$3"
    local instance_id="$4"

    az vmss get-instance-view \
        --name "$vmss_name" \
        --resource-group "$resource_group" \
        --subscription "$subscription" \
        --instance-id "$instance_id" \
        -o json | jq -r '.statuses[] | select(.code | startswith("PowerState/")) | .code'
}

# Get power state of all instances in a VMSS
#
# param:
#   $1 - vmss_name: name of the VMSS
#   $2 - resource_group: resource group of the VMSS
#   $3 - subscription: subscription of the VMSS
#
# return:
#   "running" if all instances are running
#   "deallocated" if all instances are deallocated
#   "partial" if some instances are running and some are deallocated
function get_vmss_power_state() {
    local vmss_name="$1"
    local resource_group="$2"
    local subscription="$3"

    # Get list of instance IDs
    local instances
    instances=$(az vmss list-instances \
        --name "$vmss_name" \
        --resource-group "$resource_group" \
        --subscription "$subscription" \
        -o json | jq -r '.[].instanceId')

    local running_count=0
    local total_count=0

    # Get power states of all instances
    for instance_id in $instances; do
        total_count=$((total_count + 1))
        
        local state
        state=$(get_vmss_instance_power_state "$vmss_name" "$resource_group" "$subscription" "$instance_id")

        if [ "$state" = "PowerState/running" ]; then
            running_count=$((running_count + 1))
        fi
    done

    # Determine the overall power state
    if [ "$running_count" -eq "$total_count" ]; then
        echo "running"
    elif [ "$running_count" -eq 0 ]; then
        echo "deallocated"
    else
        echo "partial"
    fi
}