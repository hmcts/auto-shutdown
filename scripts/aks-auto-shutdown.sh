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
    echo "About to shutdown cluster $NAME (rg:$RESOURCE_GROUP)"
    echo az aks stop --resource-group $RESOURCE_GROUP --name $NAME || echo Ignoring any errors stopping cluster
    az aks stop --resource-group $RESOURCE_GROUP --name $NAME || echo Ignoring any errors stopping cluster
    echo
    done
done
