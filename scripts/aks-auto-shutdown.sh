#!/usr/bin/env bash
set -e

#Parameters

SUBSCRIPTION_ID="a8140a9e-f1b0-481f-a4de-09e2ee23f7ab"
PROJECT="ss"
SERVICE="aks"
ENVIRONMENT="sbox"
CLUSTER_NAME="00"


#Variables

RESOURCE_GROUP="${PROJECT}"-"${ENVIRONMENT}"-"${CLUSTER_NAME}"-rg
RESOURCE_NAME="${PROJECT}"-"${ENVIRONMENT}"-"${CLUSTER_NAME}"-"${SERVICE}"

CHECK_TAG_CMD=`az tag list --resource-id /subscriptions/"${SUBSCRIPTION_ID}"/resourcegroups/"${RESOURCE_GROUP}"/providers/Microsoft.ContainerService/managedClusters/"${RESOURCE_NAME}" -o yaml | grep autoShutdown`

CONDITION="autoShutdown: 'true'"

CLUSTER_NAME_OUTPUT=$(az aks show --name $RESOURCE_NAME --resource-group $RESOURCE_GROUP -o yaml | grep "name: $RESOURCE_NAME")
POWER_STATE_OUTPUT=$(az aks show --name $RESOURCE_NAME --resource-group $RESOURCE_GROUP -o yaml | grep -A 35 "name: $RESOURCE_NAME" | grep -A 1 "powerState:")


#Functions

function check_tag {
    if [[ $CHECK_TAG_CMD =~ $CONDITION ]]; then
        echo "yay"
        echo "${RESOURCE_NAME} has got tag ${CONDITION}"
    else
        echo "oops"
        echo "Error!"
        printf "${RESOURCE_NAME} has not got tag ${CONDITION}, instead got: \n ${CHECK_TAG_CMD}\n"
        exit 125
    fi
}

function show_cluster_status {
    az account set --subscription $SUBSCRIPTION_ID
    echo $CLUSTER_NAME_OUTPUT
    echo $POWER_STATE_OUTPUT
}

# function stop_aks_cluster {
#     az aks stop --name $RESOURCE_NAME --resource-group $RESOURCE_GROUP
# }

# function start_aks_cluster {
#     az aks start --name $RESOURCE_NAME --resource-group $RESOURCE_GROUP
# }



#Run Functions
check_tag
show_cluster_status
