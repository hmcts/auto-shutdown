#!/usr/bin/env bash

function ts_echo() {
	date +"%H:%M:%S $(printf "%s " "$@")"
}
if [[ $SELECTED_ENV == "sbox" ]]; then
	SELECTED_ENV="box"
fi
if [[ $SELECTED_ENV == "test/perftest" ]] && [[ $PROJECT == "CFT" ]]; then
	SELECTED_ENV="perftest"
elif [[ $SELECTED_ENV == "test/perftest" ]] && [[ $PROJECT == "SDS" ]]; then
	SELECTED_ENV="test"
elif [[ $SELECTED_ENV == "preview/dev" ]] && [[ $PROJECT == "SDS" ]]; then
	SELECTED_ENV="dev"
elif [[ $SELECTED_ENV == "preview/dev" ]] && [[ $PROJECT == "CFT" ]]; then
	SELECTED_ENV="preview"
elif [[ $SELECTED_ENV == "aat/staging" ]] && [[ $PROJECT == "SDS" ]]; then
	SELECTED_ENV="stg"
elif [[ $SELECTED_ENV == "aat/staging" ]] && [[ $PROJECT == "CFT" ]]; then
	SELECTED_ENV="aat"
fi
SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<<$SUBSCRIPTIONS | while read subcription; do
	SUBSCRIPTION_ID=$(jq -r '.id' <<<$subcription)
	SUBSCRIPTION_NAME=$(jq -r '.name' <<<$subcription)
	if [[ $PROJECT == "SDS" ]] && [[ $SUBSCRIPTION_NAME =~ "DCD-" ]]; then
		continue
	fi
	if [[ $PROJECT == "CFT" ]] && [[ $SUBSCRIPTION_NAME =~ "SHAREDSERVICES" ]]; then
		continue
	fi
	az account set -s $SUBSCRIPTION_ID

	SERVERS=$(az resource list --resource-type Microsoft.Sql/managedInstances --query "[?tags.autoShutdown == 'true']" -o json)
	jq -c '.[]' <<<$SERVERS | while read server; do
		ID=$(jq -r '.id' <<<$server)
		NAME=$(jq -r '.name' <<<$server)
		if [[ $NAME =~ $SELECTED_ENV ]]; then
			status=$(az sql mi show  --ids $ID --query "state")
			if [[ "$status" != *"Ready"* ]]; then
				ts_echo "Starting sql managed-instance show  in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<<$server)  Name: $NAME"
				az sql mi start --ids $ID --no-wait || echo Ignoring error starting $NAME
			fi
		fi
	done
done
