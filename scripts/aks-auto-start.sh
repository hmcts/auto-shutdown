# #!/usr/bin/env bash
# set -e

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do
    SUBSCRIPTION_ID=$(jq -r '.id' <<< $subscription)
    az account set -s $SUBSCRIPTION_ID
    CLUSTERS=$(az resource list \
    --resource-type Microsoft.ContainerService/managedClusters \
    --query "[?tags.autoShutdown == 'true']" -o json)

    jq -c '.[]' <<< $CLUSTERS | while read cluster; do
    RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $cluster)
    NAME=$(jq -r '.name' <<< $cluster)
    echo "About to start cluster $NAME (rg:$RESOURCE_GROUP)"
    echo az aks start --resource-group $RESOURCE_GROUP --name $NAME || echo Ignoring any errors starting cluster
    az aks start --resource-group $RESOURCE_GROUP --name $NAME || echo Ignoring any errors starting cluster
    echo
    done
done