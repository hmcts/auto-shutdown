#!/usr/bin/env bash
set -e
registrySlackWebhook=$1

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
        az aks start --resource-group $RESOURCE_GROUP --name $NAME || echo Ignoring any errors starting cluster $NAME 
        BUSINESS_AREA=$(jq -r '.tags.businessArea' <<< $cluster)
        if [[ "$BUSINESS_AREA" == "Cross-Cutting" ]]; then
            APP="toffee"
        elif [[ "$BUSINESS_AREA" == "CFT" ]]; then
            APP="plum"
        fi

        ENVIRONMENT=$(jq -r '.tags.environment' <<< $cluster)

        echo "Test that $APP works in $ENVIRONMENT after $NAME start-up"
        statuscode=$(curl --max-time 30 --retry 20 --retry-delay 15 -s -o /dev/null -w "%{http_code}"  https://$APP.$ENVIRONMENT.platform.hmcts.net)

        if [[ $statuscode -eq 200 ]]; then
            echo "$APP works in $ENVIRONMENT after $NAME start-up"
        else
            echo "$APP does not work in $ENVIRONMENT after $NAME start-up"
            curl -X POST --data-urlencode "payload={\"channel\": \"#green-daily-checks\", \"username\": \"AKS Auto-Start\", \"text\": \"$APP does not work in $ENVIRONMENT after $NAME start-up. Please check cluster.\", \"icon_emoji\": \":tim-webster:\"}" \
            ${registrySlackWebhook} 
        fi

    done
done
