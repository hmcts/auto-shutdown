#!/bin/bash

# Allowed subscriptions
ALLOWED_SUBSCRIPTIONS=("a8140a9e-f1b0-481f-a4de-09e2ee23f7ab")

function get_vmss() {
    log "----------------------------------------------"
    log "Running az graph query for VMSS within allowed subscriptions..."

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

    # Query VMSS and filter by allowed subscriptions
    az graph query -q "
    resources
    | where type =~ 'Microsoft.Compute/virtualMachineScaleSets'
    | where subscriptionId in ('7a4e3bd5-ae3a-4d0c-b441-2188fee3ff1c', '1c4f0704-a29e-403d-b719-b90c34ef14c9', 'bf308a5c-0624-4334-8ff8-8dca9fd43783')
    | where tags.autoShutdown == 'true'
    $env_selector
    $area_selector
    | project name, resourceGroup, subscriptionId, ['tags'], properties.instanceView.statuses[0].code, ['id']
    " --first 1000 -o json

    log "az graph query for VMSS complete"
}

# Function to extract VMSS details from JSON input
function get_vm_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup // "value_not_retrieved"' <<< $vm)
  VMSS_NAME=$(jq -r '.name' <<< $vm)
  ENVIRONMENT=$(jq -r '.tags.environment // .tags.Environment // "tag_not_set"' <<< "$vm")
  BUSINESS_AREA=$(jq -r 'if (.tags.businessArea // .tags.BusinessArea // "tag_not_set" | ascii_downcase) == "ss" then "cross-cutting" else (.tags.businessArea // .tags.BusinessArea // "tag_not_set" | ascii_downcase) end' <<< $vm)
  STARTUP_MODE=$(jq -r '.tags.startupMode // "false"' <<< $vm)
  VMSS_STATE=$(jq -r '.properties.instanceView.statuses[0].code' <<< $vm)
  SUBSCRIPTION=$(jq -r '.subscriptionId' <<< $vm)

  # Validate subscription
  if [[ ! " ${ALLOWED_SUBSCRIPTIONS[@]} " =~ " ${SUBSCRIPTION} " ]]; then
      log "Skipping VMSS $VMSS_NAME in subscription $SUBSCRIPTION (not in allowed list)"
      return 1
  fi

  VMSS_ID="/subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachineScaleSets/$VMSS_NAME"
}

function vmss_state_messages() {
    ts_echo_color GREEN "About to run $MODE operation on VMSS: $VMSS_NAME in Resource Group: $RESOURCE_GROUP"
    ts_echo_color GREEN  "Command to run: az vmss $MODE --ids $VMSS_ID --no-wait || echo Ignoring any errors while $MODE operation on VMSS"
}
