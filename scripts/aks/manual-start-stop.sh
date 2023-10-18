#!/usr/bin/env bash

# Define an associative array for subscription names, cluster name prefixes
declare -A SUBSCRIPTION_CLUSTERMAP

SUBSCRIPTION_CLUSTERMAP["CFT,Sandbox"]="DCD-CFTAPPS-SBOX,CFT-SBOX"
SUBSCRIPTION_CLUSTERMAP["CFT,AAT / Staging"]="DCD-CFTAPPS-STG,CFT-AAT"
SUBSCRIPTION_CLUSTERMAP["CFT,Test / Perftest"]="DCD-CFTAPPS-TEST,CFT-PERFTEST"
SUBSCRIPTION_CLUSTERMAP["CFT,Preview / Dev"]="DCD-CFTAPPS-DEV,CFT-PREVIEW"
SUBSCRIPTION_CLUSTERMAP["CFT,Demo"]="DCD-CFTAPPS-DEMO,CFT-DEMO"
SUBSCRIPTION_CLUSTERMAP["CFT,ITHC"]="DCD-CFTAPPS-ITHC,CFT-ITHC"
SUBSCRIPTION_CLUSTERMAP["CFT,PTL"]="DTS-CFTPTL-INTSVC,CFT-PTL"
SUBSCRIPTION_CLUSTERMAP["CFT,PTLSBOX"]="DTS-CFTSBOX-INTSVC,CFT-PTLSBOX"

SUBSCRIPTION_CLUSTERMAP["SDS,Sandbox"]="DTS-SHAREDSERVICES-SBOX,SS-SBOX"
SUBSCRIPTION_CLUSTERMAP["SDS,AAT / Staging"]="DTS-SHAREDSERVICES-STG,SS-STG"
SUBSCRIPTION_CLUSTERMAP["SDS,Test / Perftest"]="DTS-SHAREDSERVICES-TEST,SS-TEST"
SUBSCRIPTION_CLUSTERMAP["SDS,Preview / Dev"]="DTS-SHAREDSERVICES-DEV,SS-DEV"
SUBSCRIPTION_CLUSTERMAP["SDS,Demo"]="DTS-SHAREDSERVICES-DEMO,SS-DEMO"
SUBSCRIPTION_CLUSTERMAP["SDS,ITHC"]="DTS-SHAREDSERVICES-ITHC,SS-ITHC"
SUBSCRIPTION_CLUSTERMAP["SDS,PTL"]="DTS-SHAREDSERVICESPTL,SS-PTL"
SUBSCRIPTION_CLUSTERMAP["SDS,PTLSBOX"]="DTS-SHAREDSERVICESPTL-SBOX,SS-PTLSBOX"

function subscription() {
  key="${PROJECT},${SELECTED_ENV}"
  SUBSCRIPTION=$(echo ${SUBSCRIPTION_CLUSTERMAP[$key]} | cut -d ',' -f 1)
  CLUSTER_PREFIX=$(echo ${SUBSCRIPTION_CLUSTERMAP[$key]} | cut -d ',' -f 2)

	if [[ $INSTANCES == 'All' ]]; then
		INSTANCES=(00 01)
	fi

	az account set -n $SUBSCRIPTION
	ts_echo $SUBSCRIPTION selected
}

function cluster() {
	RESOURCE_GROUP=$(jq -r '.resourceGroup' <<<$cluster)
	NAME=$(jq -r '.name' <<<$cluster)
}

function ts_echo() {
	date +"%H:%M:%S $(printf "%s " "$@")"
}

MODE=${1:-start}

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

subscription
for INSTANCE in ${INSTANCES[@]}; do
	CLUSTERS=$(az resource list \
		--name $CLUSTER_PREFIX"-"$INSTANCE"-aks" \
		--query "[?tags.autoShutdown == 'true']" -o json)
	jq -c '.[]' <<<$CLUSTERS | while read cluster; do
		cluster

		ts_echo "About to $MODE cluster $NAME (rg:$RESOURCE_GROUP)"
		az aks $MODE --resource-group $RESOURCE_GROUP --name $NAME --no-wait || ts_echo Ignoring any errors while doing $MODE operation on cluster $NAME

		ts_echo "Waiting 2 mins to give clusters time to $MODE before testing pods"
		sleep 120
		ts_echo $NAME
		RESULT=$(az aks show --name $NAME -g $RESOURCE_GROUP | jq -r .powerState.code)
		ts_echo "${RESULT}"
	done
done
