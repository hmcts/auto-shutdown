#!/usr/bin/env bash
# set -x
shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'

source scripts/common/common-functions.sh
source scripts/aks/common-functions.sh
source scripts/vmss/common-functions.sh
source scripts/vm/common-functions.sh
source scripts/appgateway/common-functions.sh
source scripts/flexible-server/common-functions.sh
source scripts/sqlmi/common-functions.sh

node_count=0
business_area_entry=$(jq -r '. | last | .business_area' issues_list.json)

# Declare associative array
declare -A sku_sizes

# Function to add resource info and count to array
# Create new entry if resource does not already exist. Update entry if resource already exists in array
# Parameters: resource_type, sku, os_or_tier, count
function countResource() {
    local resource_type="$1"
    local sku="$2" 
    local os_or_tier="$3"
    local count="$4"
    local key="${resource_type},${sku},${os_or_tier}"
    
    if [[ -v sku_sizes["$key"] ]]; then
        echo "adding $count instances to existing count for $key"
        local existing_count=$(echo "${sku_sizes["$key"]}")
        local new_count=$((existing_count + count))
        sku_sizes["$key"]=$new_count
    else
        echo "adding $key to array with $count instances"
        sku_sizes["$key"]=$count
    fi
}

# Legacy function for backward compatibility with existing AKS/VMSS code
function countSku() {
    countResource "VM" "$1" "$3" "$2"
}
# Print array summary
function nodeSummary() {
    for resource_info in "${!sku_sizes[@]}"; do
        echo "${resource_info},${sku_sizes[${resource_info}]}"
    done
}

# Get non-AKS VM Scale Sets instances details from Azure
function get_vmss_costs() {
    VMSS_INSTANCES=$(get_vmss_instances)

    while read vmss; do
        get_vmss_instance_details "$vmss"
        local vmss_env=$(echo $ENVIRONMENT | sed -e 's/testing/test/' -e 's/development/dev/')
        local vmss_business_area=$BUSINESS_AREA

        if [[ $env_entry =~ $vmss_env ]] && [[ $vmss_business_area == $business_area_entry ]]; then
            echo "Including $VMSS_NAME VMSS instance number $VMSS_INSTANCE_IDX in shutdown skip cost. It has a size of $VMSS_SKU and OS of $VMSS_OS"
            countSku $VMSS_SKU 1 "$VMSS_OS"
        fi
        
    done < <(jq -c '.data[]' <<< $VMSS_INSTANCES)
}

# Get Virtual Machines details from Azure
function get_vm_costs() {
    # Enhanced query to include VM size information
    VMS=$(az graph query -q "
    resources
    | where type =~ 'Microsoft.Compute/virtualMachines'
    | where tags.autoShutdown == 'true'
    | where tags.environment =~ '$env_entry'
    | where tolower(tags.businessArea) == tolower('$business_area_entry')
    | project name, resourceGroup, subscriptionId, tags, properties.extended.instanceView.powerState.displayStatus, properties.hardwareProfile.vmSize, properties.storageProfile.osDisk.osType, id
    | where not(tags.builtFrom == 'https://github.com/hmcts/bastion')
    " --first 1000 -o json)

    while read vm; do
        get_vm_details
        local vm_env=$ENVIRONMENT
        local vm_business_area=$BUSINESS_AREA

        if [[ $env_entry =~ $vm_env ]] && [[ $vm_business_area == $business_area_entry ]]; then
            # Extract VM size and OS from the enhanced query
            local vm_size=$(jq -r '.properties_hardwareProfile_vmSize // "Standard_D2s_v3"' <<< "$vm")
            local vm_os=$(jq -r '.properties_storageProfile_osDisk_osType // "Linux"' <<< "$vm")
            
            echo "Including $VM_NAME VM in shutdown skip cost. Size: $vm_size, OS: $vm_os"
            
            countResource "VM" "$vm_size" "$vm_os" 1
        fi
        
    done < <(jq -c '.data[]' <<< $VMS)
}

# Get Application Gateway details from Azure
function get_appgateway_costs() {
    # Enhanced query to include SKU information
    APP_GATEWAYS=$(az graph query -q "
    resources
    | where type =~ 'microsoft.network/applicationgateways'
    | where tags.autoShutdown == 'true'
    | where tags.environment =~ '$env_entry'
    | where tolower(tags.businessArea) == tolower('$business_area_entry')
    | project name, resourceGroup, subscriptionId, tags, properties.operationalState, properties.sku.tier, properties.sku.name, properties.sku.capacity, id
    " --first 1000 -o json)

    while read application_gateway; do
        get_application_gateways_details
        local appgw_env=$ENVIRONMENT
        local appgw_business_area=$BUSINESS_AREA

        if [[ $env_entry =~ $appgw_env ]] && [[ $appgw_business_area == $business_area_entry ]]; then
            # Extract actual SKU information
            local sku_tier=$(jq -r '.properties_sku_tier // "Standard_v2"' <<< "$application_gateway")
            local sku_name=$(jq -r '.properties_sku_name // "Standard_v2"' <<< "$application_gateway")
            local capacity=$(jq -r '.properties_sku_capacity // 1' <<< "$application_gateway")
            
            echo "Including $APPLICATION_GATEWAY_NAME Application Gateway in shutdown skip cost. SKU: $sku_tier, Capacity: $capacity"
            
            # For Application Gateways, capacity affects pricing
            countResource "ApplicationGateway" "$sku_tier" "$sku_name" "$capacity"
        fi
        
    done < <(jq -c '.data[]' <<< $APP_GATEWAYS)
}

# Get Flexible Server details from Azure
function get_flexible_server_costs() {
    # Enhanced query to include SKU information
    FLEXIBLE_SERVERS=$(az graph query -q "
    resources
    | where type =~ 'microsoft.dbforpostgresql/flexibleservers'
    | where tags.autoShutdown == 'true'
    | where tags.environment =~ '$env_entry'
    | where tolower(tags.businessArea) == tolower('$business_area_entry')
    | project name, resourceGroup, subscriptionId, tags, properties.state, properties.sku.tier, properties.sku.name, id
    " --first 1000 -o json)

    while read flexibleserver; do
        get_flexible_sql_server_details
        local server_env=$ENVIRONMENT
        local server_business_area=$BUSINESS_AREA

        if [[ $env_entry =~ $server_env ]] && [[ $server_business_area == $business_area_entry ]]; then
            # Extract actual SKU information
            local sku_tier=$(jq -r '.properties_sku_tier // "GeneralPurpose"' <<< "$flexibleserver")
            local sku_name=$(jq -r '.properties_sku_name // "Standard_D2ds_v4"' <<< "$flexibleserver")
            
            echo "Including $SERVER_NAME Flexible Server in shutdown skip cost. SKU: $sku_tier/$sku_name"
            
            # Build PostgreSQL-style SKU name
            local postgres_sku="${sku_tier:0:2}_${sku_name}"
            
            countResource "FlexibleServer" "$postgres_sku" "PostgreSQL" 1
        fi
        
    done < <(jq -c '.data[]' <<< $FLEXIBLE_SERVERS)
}

# Get SQL Managed Instance details from Azure
function get_sqlmi_costs() {
    # Enhanced query to include SKU information
    SQL_MI_SERVERS=$(az graph query -q "
    resources
    | where type =~ 'microsoft.sql/managedinstances'
    | where tags.autoShutdown == 'true'
    | where tags.environment =~ '$env_entry'
    | where tolower(tags.businessArea) == tolower('$business_area_entry')
    | project name, resourceGroup, subscriptionId, tags, properties.state, properties.sku.tier, properties.sku.name, properties.sku.family, properties.vCores, id
    " --first 1000 -o json)

    while read server; do
        get_sql_mi_server_details
        local sqlmi_env=$ENVIRONMENT
        local sqlmi_business_area=$BUSINESS_AREA

        if [[ $env_entry =~ $sqlmi_env ]] && [[ $sqlmi_business_area == $business_area_entry ]]; then
            # Extract actual SKU information
            local sku_tier=$(jq -r '.properties_sku_tier // "GeneralPurpose"' <<< "$server")
            local sku_name=$(jq -r '.properties_sku_name // "GP_Gen5"' <<< "$server")
            local sku_family=$(jq -r '.properties_sku_family // "Gen5"' <<< "$server")
            local vcores=$(jq -r '.properties_vCores // 4' <<< "$server")
            
            echo "Including $SERVER_NAME SQL Managed Instance in shutdown skip cost. SKU: $sku_tier, vCores: $vcores"
            
            # Build SQL MI-style SKU name
            local sqlmi_sku="${sku_tier:0:2}_${sku_family}_${vcores}"
            
            countResource "SqlManagedInstance" "$sqlmi_sku" "$sku_tier" 1
        fi
        
    done < <(jq -c '.data[]' <<< $SQL_MI_SERVERS)
}

# Get AKS nodepool details from Azure, node count, nodepool name, nodepool SKU...
function get_aks_costs() {
    CLUSTERS=$(get_clusters)

    while read cluster; do
        get_cluster_details
        cluster_env=$(echo $CLUSTER_NAME | cut -d'-' -f2)
        cluster_env=${cluster_env/#sbox/Sandbox}
        cluster_env=${cluster_env/stg/Staging}
        cluster_business_area=$(echo $CLUSTER_NAME | cut -d'-' -f1)
        cluster_business_area=${cluster_business_area/ss/cross-cutting}

        if [[ ${env_entry} =~ ${cluster_env} ]] && [[ $cluster_business_area == $business_area_entry ]]; then
            nodepool_details=$(az aks nodepool list --cluster-name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION -o json)
            while read nodepool; do
                nodepool_count=$(jq -r '."count"' <<< $nodepool)
                nodepool_name=$(jq -r '."name"' <<< $nodepool)
                nodepool_sku_output=$(jq -r '."vmSize"' <<< $nodepool)
                nodepool_os=$(jq -r '."osType"' <<< $nodepool)
                osType="$nodepool_os"

                echo "Including $cluster_name in shutdown skip cost. It has $nodepool_count nodes with a size of $nodepool_sku_output in nodepool $nodepool_name and OS of $nodepool_os"
                countSku $nodepool_sku_output $nodepool_count $osType
                continue
            done < <(jq -c '.[]' <<<$nodepool_details)
        fi
    done < <(jq -c '.data[]' <<<$CLUSTERS) # end_of_cluster_loop
}

function read_latest_issue() {
    business_area_entry=$(jq -r '. | last | .business_area' issues_list.json)
    team_name=$(jq -r '. | last | .team_name' issues_list.json)
    env_entry=$(jq -r '. | last | .environment' issues_list.json)
    start_date=$(jq -r '. | last | .start_date' issues_list.json)
    end_date=$(jq -r '. | last | .end_date' issues_list.json)
    request_url=$(jq -r '. | last | .issue_link' issues_list.json)
    change_jira_id=$(jq -r '. | last | .change_jira_id' issues_list.json)
    justification=$(jq -r '. | last | .justification' issues_list.json)
}

# Remove temp text file
rm sku_details.txt

# Read the latest issue from the issues_list.json file
read_latest_issue

# Get AKS cluster information to allow cost estimates to be calculated
get_aks_costs

# Get VM Scale Sets information to allow cost estimates to be calculated
get_vmss_costs

# Get Virtual Machines information to allow cost estimates to be calculated
get_vm_costs

# Get Application Gateway information to allow cost estimates to be calculated
get_appgateway_costs

# Get Flexible Server information to allow cost estimates to be calculated
get_flexible_server_costs

# Get SQL Managed Instance information to allow cost estimates to be calculated
get_sqlmi_costs

# Add GitHub env vars
echo START_DATE=$start_date >>$GITHUB_ENV
echo END_DATE=$end_date >>$GITHUB_ENV
echo BUSINESS_AREA_ENTRY=$business_area_entry >>$GITHUB_ENV
echo TEAM_NAME=$team_name >>$GITHUB_ENV
echo REQUEST_URL=$request_url >>$GITHUB_ENV
echo CHANGE_JIRA_ID=$change_jira_id >>$GITHUB_ENV
echo ENVIRONMENT=$env_entry >>$GITHUB_ENV
echo JUSTIFICATION=$justification >>$GITHUB_ENV

# Call node summary function and output to tempory text file
# Temp file used by "cost-calculator.py" script for cost calculations
nodeSummary >>sku_details.txt

# Adding test entry to cause cost failure scenario. Uncomment as needed
#echo "Standard_D4ds_v5test,Linux,1" >>sku_details.txt