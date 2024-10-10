#!/usr/bin/env bash
#set -x
shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'

node_count=0
business_area_entry=$(jq -r '. | last | .business_area' issues_list.json)
#declare associative array
declare -A sku_sizes

source scripts/aks/set-subscription.sh
#Function to add SKU and node count to array.
#Create new entry if SKU does not already exist. Update entry if SKU already exists in array.
function countSku() {
    if [ -v sku_sizes[$1$3] ]; then
        echo "adding $nodepool_count nodes to existing count for $1$3"
        sku_count=$(echo "${sku_sizes[$1$3]}")
        node_sku_count=$(($sku_count + $nodepool_count))
        sku_sizes[$1$3]=$node_sku_count
    else
        echo "adding $1 to array with $2 nodes"
        sku_sizes[$1$3]=$2
    fi
}
#Print array summary
function nodeSummary() {
    for sku in "${!sku_sizes[@]}"; do
        echo "${sku},${sku_sizes[${sku}]}"
    done
}
#Get nodepool details from Azure, node count, nodepool name, nodepool SKU...
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
        team_name=$(jq -r '. | last | .team_name' issues_list.json)
        env_entry=$(jq -r '. | last | .environment' issues_list.json)
        start_date=$(jq -r '. | last | .start_date' issues_list.json)
        end_date=$(jq -r '. | last | .end_date' issues_list.json)
        request_url=$(jq -r '. | last | .issue_link' issues_list.json)
        change_jira_id=$(jq -r '. | last | .change_jira_id' issues_list.json)
        justification=$(jq -r '. | last | .justification' issues_list.json)

        if [[ ${env_entry} =~ ${cluster_env} ]] && [[ $cluster_business_area == $business_area_entry ]]; then
            nodepool_details=$(az aks nodepool list --cluster-name $cluster_name --resource-group $RESOURCE_GROUP -o json)
            while read nodepool; do
                nodepool_count=$(jq -r '."count"' <<< $nodepool)
                nodepool_name=$(jq -r '."name"' <<< $nodepool)
                nodepool_sku_output=$(jq -r '."vmSize"' <<< $nodepool)
                nodepool_os=$(jq -r '."osType"' <<< $nodepool)
                osType=",$nodepool_os"

                echo "Including $cluster_name in shutdown skip cost. It has $nodepool_count nodes with a size of $nodepool_sku_output in nodepool $nodepool_name and OS of $nodepool_os"
                countSku $nodepool_sku_output $nodepool_count $osType
                continue
            done < <(jq -c '.[]' <<<$nodepool_details)
        fi
    done < <(jq -c '.[]' <<<$CLUSTERS) # end_of_cluster_loop
}

#Set subscription based on user entry.
#If statements used to deal with subscription naming convention and enviornment dropdown values. Eg "AAT / Staging"
while read i; do
    PROJECT="CFT"
    if [[ $business_area_entry =~ "Cross-Cutting" ]]; then
        PROJECT="SDS"
    fi
    SELECTED_ENV=$i
    subscription
    get_costs
done < <(jq -r 'last | .environment[]' issues_list.json || jq -r 'last | .environment' issues_list.json)

#Add GitHub env vars
echo START_DATE=$start_date >>$GITHUB_ENV
echo END_DATE=$end_date >>$GITHUB_ENV
echo BUSINESS_AREA_ENTRY=$business_area_entry >>$GITHUB_ENV
echo TEAM_NAME=$team_name >>$GITHUB_ENV
echo REQUEST_URL=$request_url >>$GITHUB_ENV
echo CHANGE_JIRA_ID=$change_jira_id >>$GITHUB_ENV
echo ENVIRONMENT=$env_entry >>$GITHUB_ENV
echo JUSTIFICATION=$justification >>$GITHUB_ENV

#Remove temp text file.
rm sku_details.txt
#Call node summary function and output to tempory text file.
#Temp file used by "cost-calculator.py" script for cost calculations.
nodeSummary >>sku_details.txt

#adding test entry to cause cost failure scenario. Uncomment as needed.
#echo "Standard_D4ds_v5test,Linux,1" >>sku_details.txt