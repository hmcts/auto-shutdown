#!/usr/bin/env bash
#set -x
shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'

node_count=0
business_area_entry=$(jq -r '. | last | .business_area' issues_list.json)

function get_costs() {
    CLUSTERS=$(az resource list --resource-type Microsoft.ContainerService/managedClusters --query "[?tags.autoShutdown == 'true']" -o json)

    while read cluster; do
        RESOURCE_GROUP=$(jq -r '.resourceGroup' <<<$cluster)
        cluster_name=$(jq -r '.name' <<<$cluster)
        cluster_env=$(echo $cluster_name | cut -d'-' -f2)
        cluster_env=${cluster_env/#sbox/Sandbox}
        cluster_env=${cluster_env/stg/Staging}
        cluster_business_area=$(echo $cluster_name | cut -d'-' -f1)
        cluster_business_area=${cluster_business_area/ss/cross-cutting}

        business_area_entry=$(jq -r '. | last | .business_area' issues_list.json)
        env_entry=$(jq -r '. | last | .environment' issues_list.json)
        start_date=$(jq -r '. | last | .skip_start_date' issues_list.json)
        end_date=$(jq -r '. | last | .skip_end_date' issues_list.json)

        if [[ ${env_entry} =~ ${cluster_env} ]] && [[ $cluster_business_area == $business_area_entry ]]; then
            nodepool_sku=$(az aks nodepool list --cluster-name $cluster_name --resource-group $RESOURCE_GROUP | jq '.[] | select(.name=="linux")' | jq '.vmSize')
            nodepool_count=$(az aks nodepool list --cluster-name $cluster_name --resource-group $RESOURCE_GROUP | jq '.[] | select(.name=="linux")' | jq '.count')
            echo "Including $cluster_name in shutdown skip cost. It has $nodepool_count nodes with a size of $nodepool_sku"
            node_count=$(($node_count + $nodepool_count))
            continue
        fi
    done < <(jq -c '.[]' <<<$CLUSTERS) # end_of_cluster_loop
}

while read i; do
    if [[ $business_area_entry =~ "Cross-Cutting" ]]; then
        
        if [[ $i =~ "Staging" ]]; then
            az account set --name DTS-SHAREDSERVICES-STG
            get_costs
        elif [[ $i =~ "dev" ]]; then
            az account set --name DTS-SHAREDSERVICES-DEV
            get_costs
        elif [[ $i =~ "test" ]]; then
            az account set --name DTS-SHAREDSERVICES-TEST
            get_costs
        elif [[ $i =~ "sandbox" ]]; then
            az account set --name DTS-SHAREDSERVICES-SBOX
            get_costs
        elif [[ $i == "ptl" ]]; then
            az account set --name DTS-SHAREDSERVICESPTL
            get_costs
        else
            az account set --name DTS-SHAREDSERVICES-$i
            get_costs
        fi
    elif [[ $business_area_entry =~ "CFT" ]]; then
        echo "processing $i"
        if [[ $i =~ "AAT" ]]; then
            az account set --name DCD-CFTAPPS-STG
            get_costs
        elif [[ $i =~ "Preview" ]]; then
            az account set --name DCD-CFTAPPS-DEV
            get_costs
        elif [[ $i =~ "Perftest" ]]; then
            az account set --name DCD-CFTAPPS-TEST
            get_costs
        elif [[ $i =~ "Sandbox" ]]; then
            az account set --name DCD-CFTAPPS-SBOX
            get_costs
        elif [[ $i == "ptl" ]]; then
            az account set --name DTS-CFTPTL-INTSVC
            get_costs
        else
            az account set --name DCD-CFTAPPS-$i
            get_costs
        fi
    fi
done < <(jq -r 'last | .environment[]' issues_list.json || jq -r 'last | .environment' issues_list.json)

echo "==================="
echo "total nodes: $node_count with a size of $nodepool_sku"

echo AKS_NODE_COUNT=$node_count >> $GITHUB_ENV
echo AKS_NODE_SKU=$nodepool_sku >> $GITHUB_ENV
echo START_DATE=$start_date >> $GITHUB_ENV
echo END_DATE=$end_date >> $GITHUB_ENV