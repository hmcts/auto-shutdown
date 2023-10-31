#!/usr/bin/env bash

source scripts/aks/set-subscription.sh

function cluster() {
	RESOURCE_GROUP=$(jq -r '.resourceGroup' <<<$cluster)
	CLUSTER_NAME=$(jq -r '.name' <<<$cluster)
}

MODE=${1:-start}

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi


if [[ $INSTANCES == 'All' ]]; then
  INSTANCES=(00 01)
fi

subscription  # Call the subscription function from the included script
for INSTANCE in ${INSTANCES[@]}; do
	CLUSTERS=$(az resource list \
		--name $CLUSTER_PREFIX"-"$INSTANCE"-aks" \
		--query "[?tags.autoShutdown == 'true']" -o json)
	jq -c '.[]' <<<$CLUSTERS | while read cluster; do
		cluster

		ts_echo "About to $MODE cluster $CLUSTER_NAME (rg:$RESOURCE_GROUP)"
		az aks $MODE --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --no-wait || ts_echo Ignoring any errors while doing $MODE operation on cluster $CLUSTER_NAME

		ts_echo "Waiting 2 mins to give clusters time to $MODE before testing pods"
		sleep 120
		ts_echo $CLUSTER_NAME
		RESULT=$(az aks show --name $CLUSTER_NAME -g $RESOURCE_GROUP | jq -r .powerState.code)
		ts_echo "${RESULT}"
	done
done